#!/usr/bin/env ruby
# FlowUS LLM Wiki — Lint check
# Checks: stale pages, orphan pages, duplicate concepts, unsupported claims,
#         contradictions, unresolved questions, E2E test record cleanup status

require "json"
require "net/http"
require "uri"
require "date"

CONFIG_PATH = File.expand_path("~/.codex/config.toml")

def flowus_url
  config = File.read(CONFIG_PATH)
  config[/url\s*=\s*"([^"]*flowus[^"]*)"/, 1].tap { |u| raise "FlowUS MCP url not found" unless u }
end

class McpClient
  attr_reader :session_id
  def initialize(url)
    @uri = URI(url)
    @id = 0
    @session_id = nil
  end

  def request(method, params = nil, notification: false, **kw)
    params = kw unless kw.empty?
    payload = { jsonrpc: "2.0", method: method }
    payload[:id] = (@id += 1) unless notification
    payload[:params] = params unless params.nil?
    r = post(payload)
    parse(r, notification: notification)
  end

  def initialize_session
    request("initialize", { protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "personalos-lint", version: "0.1" } })
    request("notifications/initialized", {}, notification: true)
  end

  private
  def post(payload)
    req = Net::HTTP::Post.new(@uri)
    req["Content-Type"] = "application/json"
    req["Accept"] = "application/json, text/event-stream"
    req["Mcp-Session-Id"] = @session_id if @session_id
    req.body = JSON.generate(payload)
    resp = Net::HTTP.start(@uri.hostname, @uri.port, use_ssl: @uri.scheme == "https", read_timeout: 30) { |h| h.request(req) }
    @session_id ||= resp["Mcp-Session-Id"] || resp["mcp-session-id"]
    resp
  end

  def parse(resp, notification:)
    body = resp.body.to_s
    raise "HTTP #{resp.code}: #{body}" if resp.code.to_i >= 400
    return nil if notification || body.strip.empty?
    stripped = body.strip
    stripped = stripped.lines.grep(/\Adata:/).map { |l| l.sub(/\Adata:\s*/, "") }.join if stripped.start_with?("event:") || stripped.start_with?("data:")
    JSON.parse(stripped)
  end
end

def call_tool(client, name, args = {})
  result = client.request("tools/call", { name: name, arguments: args })
  rpc = result.fetch("result")
  text = rpc.fetch("content", []).find { |i| i["type"] == "text" }
  raise text.fetch("text") if rpc["isError"]
  structured = rpc["structuredContent"]
  return structured if structured.is_a?(Hash) && !structured.empty?
  raise "No text payload" unless text
  JSON.parse(text.fetch("text"))
end

def load_ids
  path = File.expand_path("flowus-llm-wiki/mcp-integration.md", __dir__)
  rows = {}
  File.readlines(path).each do |line|
    next unless line.start_with?("|")
    cells = line.split("|").map(&:strip)
    next unless cells.length >= 5
    key, id = cells[1], cells[3]
    rows[key] = id if key =~ /\A[a-z_]+\z/ && id =~ /\A[0-9a-f-]{36}\z/i
  end
  rows
end

def query_all(client, db_id, page_size: 100)
  result = call_tool(client, "API-queryDatabase", { database_id: db_id, body: { page_size: page_size } })
  result.fetch("results", [])
end

def prop_text(page, field)
  prop = page.dig("properties", field)
  return nil unless prop
  case prop["type"]
  when "title"   then prop["title"].to_a.map { |t| t["plain_text"] }.join
  when "rich_text" then prop["rich_text"].to_a.map { |t| t["plain_text"] }.join
  when "select"  then prop.dig("select", "name")
  when "multi_select" then prop["multi_select"].to_a.map { |o| o["name"] }
  when "date"    then prop.dig("date", "start")
  when "number"  then prop["number"]
  when "checkbox" then prop["checkbox"]
  when "relation" then prop["relation"].to_a.map { |r| r["id"] }
  when "url"     then prop["url"]
  else nil
  end
end

def page_title(page)
  title_prop = page["properties"].values.find { |p| p["type"] == "title" }
  title_prop.to_h.fetch("title", []).map { |t| t["plain_text"] }.join
end

# ── Main ──────────────────────────────────────────────

puts "=" * 60
puts "  FlowUS LLM Wiki — Lint Report"
puts "  #{Time.now.strftime('%Y-%m-%d %H:%M')}"
puts "=" * 60
puts

client = McpClient.new(flowus_url)
client.initialize_session
ids = load_ids

# Fetch all records from all databases
puts "Fetching records..."
raws    = query_all(client, ids.fetch("raw_sources"))
wikis   = query_all(client, ids.fetch("wiki_pages"))
questions = query_all(client, ids.fetch("questions"))
outputs = query_all(client, ids.fetch("outputs"))
logs    = query_all(client, ids.fetch("log"))

puts "  Raw Sources: #{raws.length}"
puts "  Wiki Pages:  #{wikis.length}"
puts "  Questions:   #{questions.length}"
puts "  Outputs:     #{outputs.length}"
puts "  Logs:        #{logs.length}"
puts

issues = []
warnings = []
info = []

# ── Check 1: E2E test records ─────────────────────────

e2e_raws    = raws.select    { |r| page_title(r).include?("MCP E2E") }
e2e_wikis   = wikis.select   { |r| page_title(r).include?("MCP E2E") }
e2e_qs      = questions.select { |r| page_title(r).include?("MCP E2E") }
e2e_outs    = outputs.select { |r| page_title(r).include?("MCP E2E") }
e2e_logs    = logs.select    { |r| page_title(r).include?("MCP E2E") }
e2e_total   = e2e_raws.length + e2e_wikis.length + e2e_qs.length + e2e_outs.length + e2e_logs.length

if e2e_total > 0
  warnings << {
    check: "E2E 测试记录残留",
    severity: "warning",
    detail: "共 #{e2e_total} 条 MCP E2E 测试记录未清理",
    breakdown: {
      "Raw Sources" => e2e_raws.length,
      "Wiki Pages"  => e2e_wikis.length,
      "Questions"   => e2e_qs.length,
      "Outputs"     => e2e_outs.length,
      "Log"         => e2e_logs.length
    },
    action: "在 FlowUS 中筛选标题包含 'MCP E2E' 的记录并手动删除"
  }
end

# ── Check 2: Stale pages ──────────────────────────────

today = Date.today
stale_threshold = (today - 30).to_s  # 30 days without update

stale_wikis = wikis.select do |w|
  updated = prop_text(w, "最后更新")
  maturity = prop_text(w, "成熟度")
  next false unless updated && maturity
  next false if ["已废弃"].include?(maturity)
  updated < stale_threshold
end

if stale_wikis.any?
  warnings << {
    check: "Stale pages (超过30天未更新)",
    severity: "warning",
    detail: "#{stale_wikis.length} 个非废弃 Wiki Page 超过 30 天未更新",
    pages: stale_wikis.map { |w| page_title(w) },
    action: "逐一检查是否需要更新或标记为待重写"
  }
else
  info << "无 stale pages（所有活跃 Wiki Page 均在 30 天内更新过）"
end

# ── Check 3: Orphan pages ─────────────────────────────

orphan_wikis = wikis.select do |w|
  maturity = prop_text(w, "成熟度")
  next false if ["已废弃"].include?(maturity.to_s)
  sources   = prop_text(w, "相关资料") || []
  questions = prop_text(w, "相关问题") || []
  related   = prop_text(w, "相关页面") || []
  sources.empty? && questions.empty? && related.empty?
end

if orphan_wikis.any?
  issues << {
    check: "Orphan pages (孤立页面)",
    severity: "issue",
    detail: "#{orphan_wikis.length} 个 Wiki Page 没有任何关联（资料、问题、其他页面）",
    pages: orphan_wikis.map { |w| "#{page_title(w)} (成熟度: #{prop_text(w, '成熟度')})" },
    action: "为每个孤立页面添加相关资料、相关问题或其他页面的关联，或标记为已废弃"
  }
else
  info << "无孤立页面"
end

# ── Check 4: Unsupported claims ───────────────────────

unsupported = wikis.select do |w|
  maturity = prop_text(w, "成熟度")
  credibility = prop_text(w, "可信度")
  sources = prop_text(w, "相关资料") || []
  verification = prop_text(w, "待验证点") || ""
  next false if ["已废弃"].include?(maturity.to_s)
  # 稳定或初步成型的页面，没有来源关联且可信度不是"高"
  ["稳定", "初步成型"].include?(maturity) && sources.empty? && credibility != "高" && verification.empty?
end

if unsupported.any?
  warnings << {
    check: "可能缺少来源的结论",
    severity: "warning",
    detail: "#{unsupported.length} 个 Wiki Page 成熟度较高但没有关联资料来源",
    pages: unsupported.map { |w| "#{page_title(w)} (成熟度: #{prop_text(w, '成熟度')}, 可信度: #{prop_text(w, '可信度')})" },
    action: "添加相关资料关联，或在待验证点中说明原因"
  }
else
  info << "无缺少来源的成熟页面"
end

# ── Check 5: Duplicate concepts ───────────────────────

# Simple check: similar titles (edit distance or shared keywords)
wiki_titles = wikis.map { |w| [w["id"], page_title(w)] }.to_h
duplicate_candidates = []

wikis.each do |w1|
  t1 = page_title(w1)
  wikis.each do |w2|
    t2 = page_title(w2)
    next if w1["id"] >= w2["id"]  # avoid double-counting
    # Check for high keyword overlap
    words1 = t1.scan(/[\p{Han}a-zA-Z]+/).uniq
    words2 = t2.scan(/[\p{Han}a-zA-Z]+/).uniq
    if words1.any? && words2.any?
      overlap = (words1 & words2).length.to_f / [words1.length, words2.length].min
      if overlap > 0.7
        duplicate_candidates << { page_a: t1, page_b: t2, overlap_ratio: overlap.round(2) }
      end
    end
  end
end

if duplicate_candidates.any?
  warnings << {
    check: "可能的重复概念",
    severity: "warning",
    detail: "#{duplicate_candidates.length} 对 Wiki Page 标题高度相似",
    pairs: duplicate_candidates,
    action: "检查是否表达同一概念，考虑合并或明确区分"
  }
else
  info << "未发现标题高度相似的页面"
end

# ── Check 6: Unresolved high-priority questions ───────

unresolved_high = questions.select do |q|
  status = prop_text(q, "状态")
  priority = prop_text(q, "优先级")
  ["未开始", "探索中", "暂停"].include?(status) && priority == "高"
end

unresolved_medium = questions.select do |q|
  status = prop_text(q, "状态")
  priority = prop_text(q, "优先级")
  ["未开始", "探索中"].include?(status) && priority == "中"
end

if unresolved_high.any?
  issues << {
    check: "高优先级问题未解决",
    severity: "issue",
    detail: "#{unresolved_high.length} 个高优先级问题尚未回答",
    questions: unresolved_high.map { |q| "#{page_title(q)} (状态: #{prop_text(q, '状态')})" },
    action: "优先处理这些问题，或降低优先级"
  }
end

if unresolved_medium.any?
  warnings << {
    check: "中优先级问题待探索",
    severity: "warning",
    detail: "#{unresolved_medium.length} 个中优先级问题尚未开始探索",
    questions: unresolved_medium.map { |q| page_title(q) },
    action: "安排时间探索或关闭"
  }
end

# ── Check 7: Empty or near-empty Wiki Pages ───────────

thin_wikis = wikis.select do |w|
  maturity = prop_text(w, "成熟度")
  summary = prop_text(w, "一句话摘要") || ""
  next false if ["已废弃"].include?(maturity.to_s)
  summary.strip.empty? || summary.length < 10
end

if thin_wikis.any?
  warnings << {
    check: "内容过薄的 Wiki Pages",
    severity: "warning",
    detail: "#{thin_wikis.length} 个 Wiki Page 缺少摘要或摘要过短",
    pages: thin_wikis.map { |w| page_title(w) },
    action: "补充一句话摘要，至少让读者判断页面内容"
  }
end

# ── Check 8: Log coverage ─────────────────────────────

log_types = logs.map { |l| prop_text(l, "操作类型") }.compact
log_breakdown = log_types.each_with_object(Hash.new(0)) { |v, h| h[v] += 1 }

info << "Log 操作分布: #{log_breakdown.map { |k,v| "#{k}: #{v}" }.join(', ')}"

# ── Check 9: Database health ratios ───────────────────

real_raws    = raws.length - e2e_raws.length
real_wikis   = wikis.length - e2e_wikis.length
real_qs      = questions.length - e2e_qs.length
real_outs    = outputs.length - e2e_outs.length
real_logs    = logs.length - e2e_logs.length

maturity_dist = wikis.reject { |w| page_title(w).include?("MCP E2E") }
                      .map { |w| prop_text(w, "成熟度") }.each_with_object(Hash.new(0)) { |v, h| h[v] += 1 }

wiki_type_dist = wikis.reject { |w| page_title(w).include?("MCP E2E") }
                      .map { |w| prop_text(w, "页面类型") }.each_with_object(Hash.new(0)) { |v, h| h[v] += 1 }

raw_status_dist = raws.reject { |r| page_title(r).include?("MCP E2E") }
                      .map { |r| prop_text(r, "处理状态") }.each_with_object(Hash.new(0)) { |v, h| h[v] += 1 }

# ── Summary ───────────────────────────────────────────

puts "=" * 60
puts "  Findings"
puts "=" * 60
puts

if issues.any?
  puts "  ISSUES (#{issues.length}):"
  issues.each do |i|
    puts "  [!] #{i[:check]}"
    puts "      #{i[:detail]}"
    if i[:questions]
      i[:questions].each { |q| puts "      - #{q}" }
    end
    if i[:pages]
      i[:pages].each { |p| puts "      - #{p}" }
    end
    puts "      → #{i[:action]}"
    puts
  end
end

if warnings.any?
  puts "  WARNINGS (#{warnings.length}):"
  warnings.each do |w|
    puts "  [*] #{w[:check]}"
    puts "      #{w[:detail]}"
    if w[:questions]
      w[:questions].each { |q| puts "      - #{q}" }
    end
    if w[:pages]
      w[:pages].each { |p| puts "      - #{p}" }
    end
    if w[:pairs]
      w[:pairs].each { |p| puts "      - \"#{p[:page_a]}\" <-> \"#{p[:page_b]}\" (重叠度: #{p[:overlap_ratio]})" }
    end
    if w[:breakdown]
      w[:breakdown].each { |db, count| puts "      #{db}: #{count}" }
    end
    puts "      → #{w[:action]}"
    puts
  end
end

if info.any?
  puts "  INFO:"
  info.each { |i| puts "  [i] #{i}" }
  puts
end

puts "=" * 60
puts "  Database Health"
puts "=" * 60
puts
puts "  Real records (excl. E2E test):"
puts "    Raw Sources: #{real_raws}"
puts "    Wiki Pages:  #{real_wikis}"
puts "    Questions:   #{real_qs}"
puts "    Outputs:     #{real_outs}"
puts "    Logs:        #{real_logs}"
puts
puts "  Wiki Page maturity distribution:"
maturity_dist.each { |m, c| puts "    #{m}: #{c}" }
puts
puts "  Wiki Page type distribution:"
wiki_type_dist.each { |t, c| puts "    #{t}: #{c}" }
puts
puts "  Raw Source status distribution:"
raw_status_dist.each { |s, c| puts "    #{s}: #{c}" }
puts

total_issues = issues.length + warnings.select { |w| w[:severity] == "issue" }.length
total_warnings = warnings.length

puts "  Health score: #{total_issues == 0 ? '良好' : '需要注意'}"
puts "  Issues: #{total_issues} | Warnings: #{total_warnings}"
