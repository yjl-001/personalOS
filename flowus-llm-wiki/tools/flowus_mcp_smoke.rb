#!/usr/bin/env ruby

require "json"
require "net/http"
require "uri"

CONFIG_PATH = File.expand_path("~/.codex/config.toml")

def flowus_url
  config = File.read(CONFIG_PATH)
  url = config[/url\s*=\s*"([^"]*flowus[^"]*)"/, 1]
  raise "FlowUS MCP url not found in #{CONFIG_PATH}" unless url
  url
end

def redact(text)
  text.to_s
      .gsub(/token=[^"\s]+/i, "token=<REDACTED>")
      .gsub(/(authorization:\s*bearer\s+)[a-z0-9._-]+/i, "\\1<REDACTED>")
end

class McpClient
  attr_reader :session_id

  def initialize(url)
    @uri = URI(url)
    @id = 0
    @session_id = nil
  end

  def request(method, params = nil, notification: false, **keyword_params)
    params = keyword_params unless keyword_params.empty?
    payload = {
      jsonrpc: "2.0",
      method: method
    }

    unless notification
      @id += 1
      payload[:id] = @id
    end

    payload[:params] = params unless params.nil?
    response = post(payload)
    parse_response(response, notification: notification)
  end

  def initialize_session
    result = request(
      "initialize",
      {
        protocolVersion: "2024-11-05",
        capabilities: {},
        clientInfo: {
          name: "codex-flowus-smoke-test",
          version: "0.1"
        }
      }
    )
    request("notifications/initialized", {}, notification: true)
    result
  end

  private

  def post(payload)
    request = Net::HTTP::Post.new(@uri)
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json, text/event-stream"
    request["Mcp-Session-Id"] = @session_id if @session_id
    request.body = JSON.generate(payload)

    response = Net::HTTP.start(
      @uri.hostname,
      @uri.port,
      use_ssl: @uri.scheme == "https",
      read_timeout: 30
    ) do |http|
      http.request(request)
    end

    @session_id ||= response["Mcp-Session-Id"] || response["mcp-session-id"]
    response
  end

  def parse_response(response, notification:)
    body = response.body.to_s
    if response.code.to_i >= 400
      raise "HTTP #{response.code}: #{redact(body)}"
    end
    return nil if notification || body.strip.empty?

    parse_body(body)
  end

  def parse_body(body)
    stripped = body.strip
    if stripped.start_with?("event:") || stripped.start_with?("data:")
      data_lines = stripped.lines.grep(/\Adata:/).map { |line| line.sub(/\Adata:\s*/, "") }
      stripped = data_lines.join
    end
    JSON.parse(stripped)
  end
end

def print_json(value)
  puts JSON.pretty_generate(value)
end

def tool_result_payload(result)
  rpc_result = result.fetch("result")
  text_item = rpc_result.fetch("content", []).find { |item| item["type"] == "text" }
  if rpc_result["isError"]
    raise text_item ? text_item.fetch("text") : "Tool call failed"
  end

  structured = rpc_result["structuredContent"]
  return structured if structured.is_a?(Hash) && !structured.empty?

  raise "Tool response has no text payload: #{JSON.generate(rpc_result)}" unless text_item
  JSON.parse(text_item.fetch("text"))
end

def call_tool(client, name, args = {})
  tool_result_payload(
    client.request(
      "tools/call",
      {
        name: name,
        arguments: args
      }
    )
  )
end

def integration_ids
  path = File.expand_path("../mcp-integration.md", __dir__)
  rows = {}
  File.readlines(path).each do |line|
    next unless line.start_with?("|")
    cells = line.split("|").map(&:strip)
    next unless cells.length >= 5
    key = cells[1]
    id = cells[3]
    next unless key =~ /\A[a-z_]+\z/ && id =~ /\A[0-9a-f-]{36}\z/i
    rows[key] = id
  end
  rows
end

EXPECTED_FIELDS = {
  "raw_sources" => [
    "标题", "类型", "来源链接", "作者", "收集日期", "处理状态", "主题标签", "可信度", "重要性",
    "摘要", "关键摘录", "关联 Wiki Pages", "关联 Questions", "处理记录", "最后处理时间"
  ],
  "wiki_pages" => [
    "页面名称", "页面类型", "一句话摘要", "成熟度", "可信度", "领域", "主题标签", "相关资料",
    "相关问题", "相关页面", "最后更新", "推荐复查时间", "待验证点", "更新摘要"
  ],
  "questions" => [
    "问题", "状态", "问题类型", "优先级", "当前答案", "相关资料", "相关知识页", "输出成果",
    "下一个问题", "是否沉淀为 Wiki", "创建日期", "最后更新"
  ],
  "outputs" => [
    "标题", "类型", "状态", "来源问题", "来源知识页", "来源资料", "发布位置", "创建日期",
    "最后更新", "下一步动作"
  ],
  "log" => [
    "标题", "时间", "操作类型", "涉及资料", "涉及知识页", "涉及问题", "涉及输出",
    "主要变化", "后续动作", "操作者"
  ]
}.freeze

def rt(text)
  {
    type: "text",
    text: {
      content: text,
      link: nil
    },
    annotations: {
      bold: false,
      italic: false,
      strikethrough: false,
      underline: false,
      code: false,
      color: "default"
    },
    plain_text: text,
    href: nil
  }
end

def title_value(text)
  { type: "title", title: [rt(text)] }
end

def rich_text_value(text)
  { type: "rich_text", rich_text: [rt(text)] }
end

def select_value(name)
  { type: "select", select: { name: name } }
end

def multi_select_value(*names)
  { type: "multi_select", multi_select: names.map { |name| { name: name } } }
end

def date_value(date)
  { type: "date", date: { start: date, end: nil, time_zone: nil } }
end

def relation_value(*ids)
  { type: "relation", relation: ids.map { |id| { id: id } } }
end

def checkbox_value(value)
  { type: "checkbox", checkbox: value }
end

def number_value(value)
  { type: "number", number: value }
end

def url_value(value)
  { type: "url", url: value }
end

def page_title(page)
  title_prop = page.fetch("properties").values.find { |prop| prop["type"] == "title" }
  title_prop.to_h.fetch("title", []).map { |item| item["plain_text"] }.join
end

def create_record(client, database_id, title_property, title)
  call_tool(
    client,
    "API-createPage",
    {
      parent: { database_id: database_id },
      properties: {
        title_property => title_value(title)
      }
    }
  )
end

command = ARGV.shift || "tools"
client = McpClient.new(flowus_url)
client.initialize_session

case command
when "tools"
  tools = client.request("tools/list", {})
  print_json(tools)
when "tool-names"
  tools = client.request("tools/list", {})
  rows = tools.fetch("result").fetch("tools").map do |tool|
    description = tool.fetch("description", "").lines.first.to_s.strip
    {
      name: tool.fetch("name"),
      description: description
    }
  end
  print_json(rows)
when "schema"
  tool_name = ARGV.shift
  raise "Usage: flowus_mcp_smoke.rb schema TOOL_NAME" unless tool_name
  tools = client.request("tools/list", {})
  tool = tools.fetch("result").fetch("tools").find { |candidate| candidate.fetch("name") == tool_name }
  raise "Tool not found: #{tool_name}" unless tool
  print_json(tool)
when "db-audit"
  ids = integration_ids
  audited = {}
  EXPECTED_FIELDS.each do |key, expected|
    id = ids.fetch(key)
    db = call_tool(client, "API-getDatabase", { database_id: id })
    properties = db.fetch("properties")
    actual = properties.keys
    audited[key] = {
      id: id,
      title: db.fetch("title").map { |item| item["plain_text"] }.join,
      missing_fields: expected - actual,
      extra_fields: actual - expected,
      properties: properties.transform_values do |property|
        summary = {
          "id" => property["id"],
          "type" => property["type"]
        }
        if property["type"] == "relation"
          summary["database_id"] = property.dig("relation", "database_id")
          summary["relation_type"] = property.dig("relation", "type")
          summary["synced_property_id"] = property.dig("relation", "synced_property_id")
        end
        if property["type"] == "select"
          summary["options"] = property.dig("select", "options").to_a.map { |option| option["name"] }
        end
        summary
      end
    }
  end
  print_json(audited)
when "e2e-test"
  ids = integration_ids
  today = Time.now.utc.strftime("%Y-%m-%d")
  stamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
  marker = "MCP E2E Test #{stamp}"

  raw_db = call_tool(client, "API-getDatabase", { database_id: ids.fetch("raw_sources") })
  wiki_db = call_tool(client, "API-getDatabase", { database_id: ids.fetch("wiki_pages") })
  log_db = call_tool(client, "API-getDatabase", { database_id: ids.fetch("log") })

  raw_excerpt_field = raw_db.fetch("properties").key?("关键摘录") ? "关键摘录" : "关键摘要"
  wiki_tag_property = wiki_db.fetch("properties").fetch("主题标签")
  log_wiki_field = log_db.fetch("properties").key?("涉及知识页") ? "涉及知识页" : "涉及知识库"

  raw_title = "#{marker} Raw Source"
  wiki_title = "#{marker} Wiki Page"
  related_wiki_title = "#{marker} Related Wiki Page"
  question_title = "#{marker} Question"
  output_title = "#{marker} Output"
  log_title = "#{marker} Log"

  raw_page = create_record(client, ids.fetch("raw_sources"), "标题", raw_title)
  raw_id = raw_page.fetch("id")
  call_tool(
    client,
    "API-updatePage",
    {
      page_id: raw_id,
      body: {
        properties: {
        "类型" => select_value("文章"),
        "来源链接" => url_value("https://example.com/flowus-mcp-e2e-test"),
        "作者" => rich_text_value("Codex MCP smoke test"),
        "收集日期" => date_value(today),
        "处理状态" => select_value("未处理"),
        "主题标签" => multi_select_value("AI", "知识管理"),
        "可信度" => select_value("中"),
        "重要性" => number_value(5),
        "摘要" => rich_text_value("这是一条用于验证 FlowUS MCP 端到端写入的测试资料。"),
        raw_excerpt_field => rich_text_value("测试摘录：验证数据库创建、字段更新、关联和回读。")
        }
      }
    }
  )
  call_tool(
    client,
    "API-putMarkdown",
    {
      page_id: raw_id,
      body: {
        markdown: <<~MARKDOWN
          # #{raw_title}

          ## 测试目的

          验证 FlowUS MCP 能否创建 Raw Source、写入正文、更新字段，并关联到 Wiki Pages、Questions 和 Log。
        MARKDOWN
      }
    }
  )

  wiki_properties = {
    "页面名称" => title_value(wiki_title),
    "页面类型" => select_value("概念"),
    "一句话摘要" => rich_text_value("用于验证 FlowUS MCP 写入、Markdown 正文和双向关联的测试知识页。"),
    "成熟度" => select_value("草稿"),
    "可信度" => select_value("待验证"),
    "领域" => multi_select_value("知识管理", "AI"),
    "相关资料" => relation_value(raw_id),
    "最后更新" => date_value(today),
    "待验证点" => rich_text_value("确认双向关系、查询和日志写入是否正常。"),
    "更新摘要" => rich_text_value("由 MCP 端到端测试创建。")
  }
  wiki_properties["主题标签"] =
    if wiki_tag_property["type"] == "multi_select"
      multi_select_value("MCP", "FlowUS")
    else
      rich_text_value("MCP, FlowUS")
    end

  wiki_page = create_record(client, ids.fetch("wiki_pages"), "页面名称", wiki_title)
  wiki_id = wiki_page.fetch("id")
  call_tool(
    client,
    "API-updatePage",
    {
      page_id: wiki_id,
      body: {
        properties: wiki_properties
      }
    }
  )
  call_tool(
    client,
    "API-putMarkdown",
    {
      page_id: wiki_id,
      body: {
        markdown: <<~MARKDOWN
          # #{wiki_title}

          ## 当前理解

          这是一条由 MCP 测试创建的 Wiki Page，用于确认 LLM Agent 可以直接维护 FlowUS 知识库。

          ## 更新记录

          - #{today}: MCP E2E 测试创建。
        MARKDOWN
      }
    }
  )

  related_wiki_page = create_record(client, ids.fetch("wiki_pages"), "页面名称", related_wiki_title)
  related_wiki_id = related_wiki_page.fetch("id")
  call_tool(
    client,
    "API-updatePage",
    {
      page_id: related_wiki_id,
      body: {
        properties: {
          "页面类型" => select_value("概念"),
          "一句话摘要" => rich_text_value("用于验证 Wiki Pages 自关联的相关知识页。"),
          "成熟度" => select_value("草稿"),
          "可信度" => select_value("待验证"),
          "领域" => multi_select_value("知识管理", "AI"),
          "主题标签" => multi_select_value("MCP", "FlowUS"),
          "最后更新" => date_value(today),
          "更新摘要" => rich_text_value("由 MCP E2E 自关联测试创建。")
        }
      }
    }
  )
  call_tool(
    client,
    "API-putMarkdown",
    {
      page_id: related_wiki_id,
      body: {
        markdown: <<~MARKDOWN
          # #{related_wiki_title}

          ## 当前理解

          这是一条用于验证 `Wiki Pages.相关页面` 自关联字段的测试页。
        MARKDOWN
      }
    }
  )

  call_tool(
    client,
    "API-updatePage",
    {
      page_id: wiki_id,
      body: {
        properties: {
          "相关页面" => relation_value(related_wiki_id)
        }
      }
    }
  )
  call_tool(
    client,
    "API-updatePage",
    {
      page_id: related_wiki_id,
      body: {
        properties: {
          "相关页面" => relation_value(wiki_id)
        }
      }
    }
  )

  question_page = create_record(client, ids.fetch("questions"), "问题", question_title)
  question_id = question_page.fetch("id")
  call_tool(
    client,
    "API-updatePage",
    {
      page_id: question_id,
      body: {
        properties: {
        "状态" => select_value("已回答"),
        "问题类型" => select_value("研究"),
        "优先级" => select_value("中"),
        "当前答案" => rich_text_value("MCP 已能创建记录、写正文并建立核心关联。"),
        "相关资料" => relation_value(raw_id),
        "相关知识页" => relation_value(wiki_id),
        "下一个问题" => rich_text_value("验证真实 ingest 时是否能按规则更新已有页面。"),
        "是否沉淀为 Wiki" => checkbox_value(true),
        "创建日期" => date_value(today),
        "最后更新" => date_value(today)
        }
      }
    }
  )

  output_page = create_record(client, ids.fetch("outputs"), "标题", output_title)
  output_id = output_page.fetch("id")
  call_tool(
    client,
    "API-updatePage",
    {
      page_id: output_id,
      body: {
        properties: {
        "类型" => select_value("方案"),
        "状态" => select_value("草稿"),
        "来源问题" => relation_value(question_id),
        "来源知识页" => relation_value(wiki_id),
        "来源资料" => relation_value(raw_id),
        "创建日期" => date_value(today),
        "最后更新" => date_value(today),
        "下一步动作" => rich_text_value("确认测试结果后，用真实资料跑 ingest。")
        }
      }
    }
  )

  call_tool(
    client,
    "API-updatePage",
    {
      page_id: raw_id,
      body: {
        properties: {
          "处理状态" => select_value("已入库"),
          "关联 Wiki Pages" => relation_value(wiki_id),
          "关联 Questions" => relation_value(question_id),
          "处理记录" => rich_text_value("MCP E2E 测试：已创建 Wiki Page、Question、Output，并建立关联。"),
          "最后处理时间" => date_value(today)
        }
      }
    }
  )

  log_page = create_record(client, ids.fetch("log"), "标题", log_title)
  log_id = log_page.fetch("id")
  call_tool(
    client,
    "API-updatePage",
    {
      page_id: log_id,
      body: {
        properties: {
        "时间" => date_value(today),
        "操作类型" => select_value("system"),
        "涉及资料" => relation_value(raw_id),
        log_wiki_field => relation_value(wiki_id),
        "涉及问题" => relation_value(question_id),
        "涉及输出" => relation_value(output_id),
        "主要变化" => rich_text_value("完成 FlowUS MCP 端到端测试：创建、写正文、更新状态、建立关联、写日志。"),
        "后续动作" => rich_text_value("用真实 Raw Source 跑一次 ingest。"),
        "操作者" => select_value("LLM")
        }
      }
    }
  )

  queried_raw = call_tool(
    client,
    "API-queryDatabase",
    {
      database_id: ids.fetch("raw_sources"),
      body: {
        filter: {
          property: "标题",
          title: {
            equals: raw_title
          }
        },
        page_size: 1
      }
    }
  )

  searched_raw = call_tool(
    client,
    "API-search",
    {
      body: {
        query: raw_title,
        filter: {
          property: "object",
          value: "page"
        },
        page_size: 5
      }
    }
  )

  wiki_markdown = call_tool(
    client,
    "API-getMarkdown",
    {
      page_id: wiki_id
    }
  )

  raw_back = call_tool(client, "API-getPage", { page_id: raw_id })
  wiki_back = call_tool(client, "API-getPage", { page_id: wiki_id })
  related_wiki_back = call_tool(client, "API-getPage", { page_id: related_wiki_id })
  question_back = call_tool(client, "API-getPage", { page_id: question_id })
  output_back = call_tool(client, "API-getPage", { page_id: output_id })
  log_back = call_tool(client, "API-getPage", { page_id: log_id })

  checks = {
    search_raw_by_title: searched_raw.fetch("results").any? { |page| page.fetch("id") == raw_id },
    query_bot_created_raw_by_title: queried_raw.fetch("results").any? { |page| page.fetch("id") == raw_id },
    raw_status_updated: raw_back.dig("properties", "处理状态", "select", "name") == "已入库",
    raw_links_wiki: raw_back.dig("properties", "关联 Wiki Pages", "relation").to_a.any? { |ref| ref["id"] == wiki_id },
    raw_links_question: raw_back.dig("properties", "关联 Questions", "relation").to_a.any? { |ref| ref["id"] == question_id },
    wiki_links_raw: wiki_back.dig("properties", "相关资料", "relation").to_a.any? { |ref| ref["id"] == raw_id },
    wiki_links_related_page: wiki_back.dig("properties", "相关页面", "relation").to_a.any? { |ref| ref["id"] == related_wiki_id },
    related_page_links_wiki_back: related_wiki_back.fetch("properties").values.any? do |property|
      property["type"] == "relation" && property["relation"].to_a.any? { |ref| ref["id"] == wiki_id }
    end,
    question_links_wiki: question_back.dig("properties", "相关知识页", "relation").to_a.any? { |ref| ref["id"] == wiki_id },
    output_links_question: output_back.dig("properties", "来源问题", "relation").to_a.any? { |ref| ref["id"] == question_id },
    log_links_raw: log_back.dig("properties", "涉及资料", "relation").to_a.any? { |ref| ref["id"] == raw_id },
    markdown_roundtrip: wiki_markdown.to_s.include?("MCP E2E 测试创建")
  }

  hard_checks = checks.reject { |key, _| key == :query_bot_created_raw_by_title }

  print_json(
    marker: marker,
    created: {
      raw_source: { id: raw_id, title: raw_title },
      wiki_page: { id: wiki_id, title: wiki_title },
      related_wiki_page: { id: related_wiki_id, title: related_wiki_title },
      question: { id: question_id, title: question_title },
      output: { id: output_id, title: output_title },
      log: { id: log_id, title: log_title }
    },
    checks: checks,
    passed: hard_checks.values.all?,
    notes: {
      query_database_visibility: "queryDatabase may not return pages created by the integration immediately; API-search and getPage do return them."
    }
  )
when "call"
  tool_name = ARGV.shift
  args_json = ARGV.shift || "{}"
  raise "Usage: flowus_mcp_smoke.rb call TOOL_NAME JSON_ARGS" unless tool_name
  args = JSON.parse(args_json)
  result = client.request(
    "tools/call",
    {
      name: tool_name,
      arguments: args
    }
  )
  print_json(result)
else
  raise "Unknown command: #{command}"
end
