#!/usr/bin/env ruby
# Real data end-to-end ingest test for FlowUS LLM Wiki
# Uses the FlowUS MCP to run a complete Raw Source → Wiki Page → Question → Log cycle

require "json"
require "net/http"
require "uri"

CONFIG_PATH = File.expand_path("~/.codex/config.toml")

def flowus_url
  config = File.read(CONFIG_PATH)
  # TOML format: url = "..."
  url = config[/url\s*=\s*"([^"]*flowus[^"]*)"/, 1]
  raise "FlowUS MCP url not found in #{CONFIG_PATH}" unless url
  url
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
    payload = { jsonrpc: "2.0", method: method }
    unless notification
      @id += 1
      payload[:id] = @id
    end
    payload[:params] = params unless params.nil?
    response = post(payload)
    parse_response(response, notification: notification)
  end

  def initialize_session
    result = request("initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: { name: "personalos-real-ingest", version: "0.1" }
    })
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
    response = Net::HTTP.start(@uri.hostname, @uri.port, use_ssl: @uri.scheme == "https", read_timeout: 30) { |http| http.request(request) }
    @session_id ||= response["Mcp-Session-Id"] || response["mcp-session-id"]
    response
  end

  def parse_response(response, notification:)
    body = response.body.to_s
    raise "HTTP #{response.code}: #{body}" if response.code.to_i >= 400
    return nil if notification || body.strip.empty?
    stripped = body.strip
    if stripped.start_with?("event:") || stripped.start_with?("data:")
      data_lines = stripped.lines.grep(/\Adata:/).map { |line| line.sub(/\Adata:\s*/, "") }
      stripped = data_lines.join
    end
    JSON.parse(stripped)
  end
end

def tool_result_payload(result)
  rpc_result = result.fetch("result")
  text_item = rpc_result.fetch("content", []).find { |item| item["type"] == "text" }
  raise text_item.fetch("text") if rpc_result["isError"]
  structured = rpc_result["structuredContent"]
  return structured if structured.is_a?(Hash) && !structured.empty?
  raise "Tool response has no text payload" unless text_item
  JSON.parse(text_item.fetch("text"))
end

def call_tool(client, name, args = {})
  tool_result_payload(client.request("tools/call", { name: name, arguments: args }))
end

# Property value builders
def rt(text)
  { type: "text", text: { content: text, link: nil }, plain_text: text, href: nil }
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

def number_value(value)
  { type: "number", number: value }
end

def url_value(value)
  { type: "url", url: value }
end

def checkbox_value(value)
  { type: "checkbox", checkbox: value }
end

def load_ids
  path = File.expand_path("../docs/setup/mcp-integration.md", __dir__)
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

# ── Main ──────────────────────────────────────────────

puts "=" * 60
puts "  FlowUS LLM Wiki — Real Data Ingest Test"
puts "=" * 60
puts

client = McpClient.new(flowus_url)
client.initialize_session
puts "[1/8] MCP session initialized"

ids = load_ids
today = Time.now.utc.strftime("%Y-%m-%d")
stamp = Time.now.utc.strftime("%Y%m%d%H%M%S")

# ── Step 1: Check database schemas ────────────────────

raw_db   = call_tool(client, "API-getDatabase", { database_id: ids.fetch("raw_sources") })
wiki_db  = call_tool(client, "API-getDatabase", { database_id: ids.fetch("wiki_pages") })
log_db   = call_tool(client, "API-getDatabase", { database_id: ids.fetch("log") })
q_db     = call_tool(client, "API-getDatabase", { database_id: ids.fetch("questions") })
out_db   = call_tool(client, "API-getDatabase", { database_id: ids.fetch("outputs") })

raw_excerpt_field = raw_db.fetch("properties").key?("关键摘录") ? "关键摘录" : "关键摘要"
log_wiki_field = log_db.fetch("properties").key?("涉及知识页") ? "涉及知识页" : "涉及知识库"

puts "[2/8] 5 databases verified"

# ── Step 2: Create a REAL Raw Source ──────────────────

raw_title = "为什么 LLM 更适合维护知识库而不是传统笔记"

raw_page = call_tool(client, "API-createPage", {
  parent: { database_id: ids.fetch("raw_sources") },
  properties: { "标题" => title_value(raw_title) }
})
raw_id = raw_page.fetch("id")
puts "[3/8] Raw Source created: #{raw_id}"

call_tool(client, "API-updatePage", {
  page_id: raw_id,
  body: {
    properties: {
      "类型" => select_value("文章"),
      "来源链接" => url_value("https://example.com/llm-wiki-vs-traditional-notes"),
      "作者" => rich_text_value("PersonalOS 真实流程测试"),
      "收集日期" => date_value(today),
      "处理状态" => select_value("未处理"),
      "主题标签" => multi_select_value("AI", "知识管理"),
      "可信度" => select_value("中"),
      "重要性" => number_value(4),
      "摘要" => rich_text_value("探讨 LLM Agent 在知识库维护中的独特优势：持续演化、交叉引用、发现矛盾、降低维护成本。传统笔记的静态特性导致知识腐烂，而 LLM 可以通过定期 ingest、lint、query 让知识库持续生长。"),
      raw_excerpt_field => rich_text_value("核心摘录：『知识库不应该是一个存储容器，而应该是一个持续演化的有机体。LLM Agent 可以像维护代码库一样维护知识库——读上下文、判断影响范围、做小而完整的更新、保留来源、写入日志。』")
    }
  }
})

call_tool(client, "API-putMarkdown", {
  page_id: raw_id,
  body: {
    markdown: <<~MARKDOWN
      # #{raw_title}

      ## 核心观点

      传统笔记软件（Notion、Obsidian、Logseq）依赖用户手动维护知识结构。随着知识量增长，用户面临三个核心问题：

      1. **知识腐烂**：旧笔记不再更新，结论过时但无人修正。
      2. **连接断裂**：不同笔记讨论同一概念，但缺少交叉引用。
      3. **维护成本高**：整理、分类、回顾都需要用户亲自操作。

      LLM Agent 通过 MCP 直接操作知识库，可以解决这些结构性难题：

      - **持续演化**：新资料进入时，Agent 主动查找相关 Wiki Pages 并更新。
      - **交叉引用**：Agent 在写入时自动建立数据库关联，不依赖用户手动链接。
      - **发现矛盾**：定期 lint 可以发现 stale pages、孤立页面、重复概念、矛盾结论。
      - **降低维护成本**：用户只需收集资料和判断方向，整理工作由 Agent 完成。

      ## 关键设计决策

      1. Raw Sources 是 source of truth，不改写事实来源。
      2. Wiki Pages 是可演化的 synthesis，可以被新资料更新、修正或拆分。
      3. Questions 驱动知识库生长——知识围绕问题生长，而不是围绕收藏生长。
      4. Log 记录每一次演化，是 Agent 的 git history。

      ## 对知识库的影响

      这个观点直接影响 PersonalOS 的设计哲学——FlowUS 不只是一个笔记工具，而是一个由 LLM 持续维护的知识库操作系统。
    MARKDOWN
  }
})

# ── Step 3: Create Wiki Page ──────────────────────────

wiki_title = "LLM 维护型知识库"

wiki_page = call_tool(client, "API-createPage", {
  parent: { database_id: ids.fetch("wiki_pages") },
  properties: { "页面名称" => title_value(wiki_title) }
})
wiki_id = wiki_page.fetch("id")
puts "[4/8] Wiki Page created: #{wiki_id}"

call_tool(client, "API-updatePage", {
  page_id: wiki_id,
  body: {
    properties: {
      "页面类型" => select_value("概念"),
      "一句话摘要" => rich_text_value("LLM 维护型知识库是一种新型知识管理系统，由 LLM Agent 通过 MCP 持续维护，实现自动摘要、交叉引用、更新旧页面、发现矛盾和写入演化日志。"),
      "成熟度" => select_value("初步成型"),
      "可信度" => select_value("中"),
      "领域" => multi_select_value("知识管理", "AI"),
      "主题标签" => multi_select_value("LLM Wiki", "PersonalOS", "MCP"),
      "相关资料" => relation_value(raw_id),
      "最后更新" => date_value(today),
      "待验证点" => rich_text_value("需要在实际使用中验证：1) 大规模知识库下 LLM 的检索准确性；2) 自动更新的质量控制；3) 用户的 review 成本是否真的降低。"),
      "更新摘要" => rich_text_value("首次创建：从《为什么 LLM 更适合维护知识库而不是传统笔记》中提炼核心概念。")
    }
  }
})

call_tool(client, "API-putMarkdown", {
  page_id: wiki_id,
  body: {
    markdown: <<~MARKDOWN
      # #{wiki_title}

      ## 一句话定义

      一种由 LLM Agent 持续维护的知识库系统，将知识管理从"手动整理"转变为"Agent 协同演化"。

      ## 当前理解

      LLM 维护型知识库的核心特征：

      1. **结构化数据库**：知识以数据库记录形式存在，每条记录有明确的字段、状态和关系。
      2. **Agent 驱动维护**：LLM Agent 通过 MCP 直接读写知识库，执行 ingest、query、lint、output 等操作。
      3. **来源保真**：原始资料（Raw Sources）不可变，Wiki Pages 可演化但始终关联来源。
      4. **日志追踪**：每次操作写入 Log，形成知识库的 git history。
      5. **问题驱动**：Questions 是知识生长的引擎，不只是 Q&A 记录。

      ## 与传统笔记的对比

      | 维度 | 传统笔记 | LLM 维护型知识库 |
      |---|---|---|
      | 维护者 | 用户 | LLM Agent + 用户 |
      | 更新频率 | 用户想起时 | 每次 ingest 自动 |
      | 交叉引用 | 手动链接 | Agent 自动关联 |
      | 矛盾检测 | 用户发现 | Lint 自动检查 |
      | 知识腐烂 | 常见 | Agent 定期复查 |
      | 演化记录 | 无 | Log 记录每次变化 |

      ## 关键来源

      - 《为什么 LLM 更适合维护知识库而不是传统笔记》
      - PersonalOS 设计文档

      ## 待验证点

      - Agent 在 50+ Wiki Pages 下能否准确找到相关页面？
      - 自动更新的质量控制边界在哪里？
      - 用户的 review 成本是否真的降低？

      ## 更新记录

      - #{today}: 首次创建，提炼自 LLM Wiki 设计理念。
    MARKDOWN
  }
})

# ── Step 4: Create a second related Wiki Page (for self-relation test) ──

related_wiki_title = "知识库即代码"

related_wiki = call_tool(client, "API-createPage", {
  parent: { database_id: ids.fetch("wiki_pages") },
  properties: { "页面名称" => title_value(related_wiki_title) }
})
related_wiki_id = related_wiki.fetch("id")
puts "[4b/8] Related Wiki Page created: #{related_wiki_id}"

call_tool(client, "API-updatePage", {
  page_id: related_wiki_id,
  body: {
    properties: {
      "页面类型" => select_value("概念"),
      "一句话摘要" => rich_text_value("将知识库视为代码库进行维护——版本控制、持续集成、代码审查、日志追踪等软件工程实践应用于知识管理。"),
      "成熟度" => select_value("草稿"),
      "可信度" => select_value("待验证"),
      "领域" => multi_select_value("知识管理"),
      "主题标签" => multi_select_value("PersonalOS"),
      "相关资料" => relation_value(raw_id),
      "最后更新" => date_value(today),
      "更新摘要" => rich_text_value("首次创建：与《LLM 维护型知识库》互为相关概念。")
    }
  }
})

# Self-relation: link both Wiki Pages to each other
call_tool(client, "API-updatePage", {
  page_id: wiki_id,
  body: { properties: { "相关页面" => relation_value(related_wiki_id) } }
})
call_tool(client, "API-updatePage", {
  page_id: related_wiki_id,
  body: { properties: { "相关页面" => relation_value(wiki_id) } }
})

# ── Step 5: Create a Question ─────────────────────────

question_title = "如何在实践中验证 LLM 维护知识库的质量？"

question_page = call_tool(client, "API-createPage", {
  parent: { database_id: ids.fetch("questions") },
  properties: { "问题" => title_value(question_title) }
})
question_id = question_page.fetch("id")
puts "[5/8] Question created: #{question_id}"

call_tool(client, "API-updatePage", {
  page_id: question_id,
  body: {
    properties: {
      "状态" => select_value("探索中"),
      "问题类型" => select_value("研究"),
      "优先级" => select_value("高"),
      "当前答案" => rich_text_value("目前计划通过真实数据测试来验证：1) 单条 ingest 的准确性和完整性；2) 多次 ingest 后的交叉引用质量；3) Lint 检查的实际发现率。具体指标待定。"),
      "相关资料" => relation_value(raw_id),
      "相关知识页" => relation_value(wiki_id),
      "下一个问题" => rich_text_value("如何设计知识库健康度的量化指标？比如 stale ratio、orphan ratio、contradiction count。"),
      "是否沉淀为 Wiki" => checkbox_value(false),
      "创建日期" => date_value(today),
      "最后更新" => date_value(today)
    }
  }
})

# ── Step 6: Update Raw Source to "已入库" ─────────────

call_tool(client, "API-updatePage", {
  page_id: raw_id,
  body: {
    properties: {
      "处理状态" => select_value("已入库"),
      "关联 Wiki Pages" => relation_value(wiki_id, related_wiki_id),
      "关联 Questions" => relation_value(question_id),
      "处理记录" => rich_text_value("已完成 ingest：提炼核心概念《LLM 维护型知识库》和《知识库即代码》，提出研究问题《如何在实践中验证 LLM 维护知识库的质量？》，建立 Wiki Page 自关联。"),
      "最后处理时间" => date_value(today)
    }
  }
})
puts "[6/8] Raw Source status updated to 已入库"

# ── Step 7: Write Log ─────────────────────────────────

log_title = "Ingest: #{raw_title}"

log_page = call_tool(client, "API-createPage", {
  parent: { database_id: ids.fetch("log") },
  properties: { "标题" => title_value(log_title) }
})
log_id = log_page.fetch("id")
puts "[7/8] Log created: #{log_id}"

call_tool(client, "API-updatePage", {
  page_id: log_id,
  body: {
    properties: {
      "时间" => date_value(today),
      "操作类型" => select_value("ingest"),
      "涉及资料" => relation_value(raw_id),
      log_wiki_field => relation_value(wiki_id, related_wiki_id),
      "涉及问题" => relation_value(question_id),
      "主要变化" => rich_text_value("处理了第一条非测试 Raw Source《#{raw_title}》。新建 Wiki Page《LLM 维护型知识库》和《知识库即代码》，建立自关联。创建研究问题《如何在实践中验证 LLM 维护知识库的质量？》。这是 PersonalOS 从技术验证走向真实使用的第一步。"),
      "后续动作" => rich_text_value("1) 继续添加 2-3 条不同类型的 Raw Sources；2) 让 Agent 回答已创建的 Question；3) 运行第一次 lint 检查结构健康度。"),
      "操作者" => select_value("LLM")
    }
  }
})

# ── Step 8: Verify everything ─────────────────────────

puts "[8/8] Verifying..."

raw_back   = call_tool(client, "API-getPage", { page_id: raw_id })
wiki_back  = call_tool(client, "API-getPage", { page_id: wiki_id })
rel_back   = call_tool(client, "API-getPage", { page_id: related_wiki_id })
q_back     = call_tool(client, "API-getPage", { page_id: question_id })
log_back   = call_tool(client, "API-getPage", { page_id: log_id })

checks = {
  raw_created: !raw_back.nil?,
  raw_status: raw_back.dig("properties", "处理状态", "select", "name") == "已入库",
  raw_links_wiki: raw_back.dig("properties", "关联 Wiki Pages", "relation").to_a.any? { |r| r["id"] == wiki_id },
  raw_links_question: raw_back.dig("properties", "关联 Questions", "relation").to_a.any? { |r| r["id"] == question_id },
  wiki_created: !wiki_back.nil?,
  wiki_links_raw: wiki_back.dig("properties", "相关资料", "relation").to_a.any? { |r| r["id"] == raw_id },
  wiki_links_related: wiki_back.dig("properties", "相关页面", "relation").to_a.any? { |r| r["id"] == related_wiki_id },
  related_links_wiki: rel_back.fetch("properties").values.any? { |p| p["type"] == "relation" && p["relation"].to_a.any? { |r| r["id"] == wiki_id } },
  question_created: !q_back.nil?,
  question_links_wiki: q_back.dig("properties", "相关知识页", "relation").to_a.any? { |r| r["id"] == wiki_id },
  log_created: !log_back.nil?,
  log_links_raw: log_back.dig("properties", "涉及资料", "relation").to_a.any? { |r| r["id"] == raw_id },
  log_type_ingest: log_back.dig("properties", "操作类型", "select", "name") == "ingest"
}

all_pass = checks.values.all?

puts
puts "=" * 60
puts "  Results"
puts "=" * 60
checks.each do |check, result|
  status = result ? "PASS" : "FAIL"
  puts "  #{status.ljust(6)} #{check}"
end
puts
puts "  Overall: #{all_pass ? 'ALL PASS' : 'SOME FAILED'}"
puts
puts "  Created records:"
puts "    Raw Source:   #{raw_id}  — #{raw_title}"
puts "    Wiki Page:    #{wiki_id}  — #{wiki_title}"
puts "    Related Wiki: #{related_wiki_id}  — #{related_wiki_title}"
puts "    Question:     #{question_id}  — #{question_title}"
puts "    Log:          #{log_id}  — #{log_title}"
puts
puts "  These are REAL records (not E2E test markers)."
puts "  They serve as the first actual content in your knowledge base."
puts "  You can find them in FlowUS under the respective databases."
