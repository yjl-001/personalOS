#!/usr/bin/env ruby
# Cleanup: remove E2E test records and duplicate Wiki Pages

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
    request("initialize", { protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "personalos-cleanup", version: "0.1" } })
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
  path = File.expand_path("../docs/setup/mcp-integration.md", __dir__)
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

def page_title(page)
  title_prop = page["properties"].values.find { |p| p["type"] == "title" }
  title_prop.to_h.fetch("title", []).map { |t| t["plain_text"] }.join
end

def prop_text(page, field)
  prop = page.dig("properties", field)
  return nil unless prop
  case prop["type"]
  when "date" then prop.dig("date", "start")
  else nil
  end
end

def search_all(client, query)
  call_tool(client, "API-search", {
    body: { query: query, filter: { property: "object", value: "page" }, page_size: 50 }
  }).fetch("results", [])
end

def query_all(client, db_id)
  call_tool(client, "API-queryDatabase", {
    database_id: db_id, body: { page_size: 100 }
  }).fetch("results", [])
end

# ── Main ──────────────────────────────────────────────

puts "=" * 60
puts "  Cleanup: E2E Test Records + Duplicate Wiki Pages"
puts "=" * 60
puts

client = McpClient.new(flowus_url)
client.initialize_session
ids = load_ids

deleted = []
kept = []

# ── Step 1: Find & delete E2E test records ───────────

puts "Searching for MCP E2E test records..."
e2e_results = search_all(client, "MCP E2E")
puts "  Found #{e2e_results.length} records with 'MCP E2E' in title"

e2e_results.each do |page|
  id = page["id"]
  title = page_title(page)
  puts "  Deleting: #{title} (#{id})"
  begin
    call_tool(client, "API-deletePage", { page_id: id })
    deleted << { type: "E2E test", title: title, id: id }
  rescue => e
    puts "    FAILED: #{e.message}"
    kept << { type: "E2E test (delete failed)", title: title, id: id, error: e.message }
  end
end
puts

# ── Step 2: Find & delete duplicate Wiki Pages ───────

puts "Searching for duplicate Wiki Pages..."
wiki_records = query_all(client, ids.fetch("wiki_pages"))
puts "  Found #{wiki_records.length} Wiki Pages total"

# Group by title
by_title = wiki_records.group_by { |w| page_title(w) }

duplicates = by_title.select { |title, pages| pages.length > 1 }
puts "  Duplicate sets: #{duplicates.length}"

duplicates.each do |title, pages|
  puts "  Title: '#{title}' has #{pages.length} copies"

  # Sort by: prefer non-E2E, then by page ID (newer pages tend to have lexicographically higher UUIDs)
  sorted = pages.sort_by { |p| [p["id"]] }.reverse

  # Keep the first (newest), delete the rest
  keep = sorted.shift
  puts "    Keeping:  #{keep["id"]} (newest)"
  kept << { type: "Wiki Page (kept)", title: title, id: keep["id"] }

  sorted.each do |dup|
    puts "    Deleting: #{dup["id"]}"
    begin
      call_tool(client, "API-deletePage", { page_id: dup["id"] })
      deleted << { type: "Duplicate Wiki Page", title: title, id: dup["id"] }
    rescue => e
      puts "      FAILED: #{e.message}"
      kept << { type: "Duplicate Wiki Page (delete failed)", title: title, id: dup["id"], error: e.message }
    end
  end
end
puts

# Also handle duplicate Raw Sources
puts "Checking for duplicate Raw Sources..."
raw_records = query_all(client, ids.fetch("raw_sources"))
raw_by_title = raw_records.group_by { |r| page_title(r) }
raw_dups = raw_by_title.select { |t, pages| pages.length > 1 }

raw_dups.each do |title, pages|
  puts "  Title: '#{title}' has #{pages.length} copies"
  sorted = pages.sort_by { |p| [p["id"]] }.reverse
  keep = sorted.shift
  puts "    Keeping:  #{keep["id"]}"
  kept << { type: "Raw Source (kept)", title: title, id: keep["id"] }

  sorted.each do |dup|
    puts "    Deleting: #{dup["id"]}"
    begin
      call_tool(client, "API-deletePage", { page_id: dup["id"] })
      deleted << { type: "Duplicate Raw Source", title: title, id: dup["id"] }
    rescue => e
      puts "      FAILED: #{e.message}"
      kept << { type: "Duplicate Raw Source (delete failed)", title: title, id: dup["id"], error: e.message }
    end
  end
end
puts

# ── Step 3: Also check for duplicate Questions and Logs ──

puts "Checking Questions..."
q_records = query_all(client, ids.fetch("questions"))
q_by_title = q_records.group_by { |q| page_title(q) }
q_dups = q_by_title.select { |t, pages| pages.length > 1 }
q_dups.each do |title, pages|
  puts "  '#{title}': #{pages.length} copies"
  sorted = pages.sort_by { |p| [p["id"]] }.reverse
  keep = sorted.shift
  kept << { type: "Question (kept)", title: title, id: keep["id"] }
  sorted.each do |dup|
    puts "    Deleting: #{dup["id"]}"
    begin
      call_tool(client, "API-deletePage", { page_id: dup["id"] })
      deleted << { type: "Duplicate Question", title: title, id: dup["id"] }
    rescue => e
      puts "      FAILED: #{e.message}"
      kept << { type: "Duplicate Question (delete failed)", title: title, id: dup["id"], error: e.message }
    end
  end
end
puts

puts "Checking Logs..."
log_records = query_all(client, ids.fetch("log"))
log_by_title = log_records.group_by { |l| page_title(l) }
log_dups = log_by_title.select { |t, pages| pages.length > 1 }
log_dups.each do |title, pages|
  puts "  '#{title}': #{pages.length} copies"
  sorted = pages.sort_by { |p| [p["id"]] }.reverse
  keep = sorted.shift
  kept << { type: "Log (kept)", title: title, id: keep["id"] }
  sorted.each do |dup|
    puts "    Deleting: #{dup["id"]}"
    begin
      call_tool(client, "API-deletePage", { page_id: dup["id"] })
      deleted << { type: "Duplicate Log", title: title, id: dup["id"] }
    rescue => e
      puts "      FAILED: #{e.message}"
      kept << { type: "Duplicate Log (delete failed)", title: title, id: dup["id"], error: e.message }
    end
  end
end

# ── Summary ───────────────────────────────────────────

puts
puts "=" * 60
puts "  Cleanup Summary"
puts "=" * 60
puts
puts "  Deleted: #{deleted.length}"
deleted.each { |d| puts "    - [#{d[:type]}] #{d[:title]}" }
puts
puts "  Kept: #{kept.length}"
kept.each { |k| puts "    - [#{k[:type]}] #{k[:title]}" }
