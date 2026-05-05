#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");
const https = require("https");
const http = require("http");

const ROOT = path.resolve(__dirname, "..");
const CONFIG_PATH = path.join(process.env.HOME || "", ".codex", "config.toml");
const INTEGRATION_PATH = path.join(ROOT, "docs", "setup", "mcp-integration.md");

function readFile(filePath) {
  return fs.readFileSync(filePath, "utf8");
}

function extractValue(text, key) {
  const match = text.match(new RegExp(`${key}\\s*=\\s*"([^"]+)"`));
  return match ? match[1] : null;
}

function extractTomlBlock(text, header) {
  const escaped = header.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = text.match(new RegExp(`\\[${escaped}\\]\\n([\\s\\S]*?)(?=\\n\\[[^\\]]+\\]\\n|$)`));
  return match ? match[1] : "";
}

function extractArrayValue(text, key) {
  const match = text.match(new RegExp(`${key}\\s*=\\s*\\[([^\\]]*)\\]`));
  if (!match) return null;
  return match[1]
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean)
    .map((item) => item.replace(/^"/, "").replace(/"$/, ""));
}

function compactEnv(env) {
  return Object.fromEntries(Object.entries(env).filter(([, value]) => value !== null && value !== undefined && value !== ""));
}

function parseIntegrationIds(text) {
  const ids = {};
  for (const line of text.split(/\r?\n/)) {
    if (!line.startsWith("|")) continue;
    const cells = line.split("|").map((cell) => cell.trim());
    if (cells.length < 5) continue;
    if (!/^[a-z_]+$/.test(cells[1])) continue;
    if (!/^[0-9a-f-]{36}$/i.test(cells[3])) continue;
    ids[cells[1]] = cells[3];
  }
  return ids;
}

function rt(text) {
  return {
    type: "text",
    text: { content: text, link: null },
    annotations: {
      bold: false,
      italic: false,
      strikethrough: false,
      underline: false,
      code: false,
      color: "default",
    },
    plain_text: text,
    href: null,
  };
}

function titleValue(text) {
  return { type: "title", title: [rt(text)] };
}

function richTextValue(text) {
  return { type: "rich_text", rich_text: [rt(text)] };
}

function selectValue(name) {
  return { type: "select", select: { name } };
}

function multiSelectValue(names) {
  return { type: "multi_select", multi_select: names.map((name) => ({ name })) };
}

function dateValue(date) {
  return { type: "date", date: { start: date, end: null, time_zone: null } };
}

function relationValue(ids) {
  return { type: "relation", relation: ids.map((id) => ({ id })) };
}

function checkboxValue(value) {
  return { type: "checkbox", checkbox: value };
}

function numberValue(value) {
  return { type: "number", number: value };
}

function parseToolText(result) {
  const textItem = (result.content || []).find((item) => item.type === "text");
  if (!textItem) throw new Error(`Tool response missing text payload: ${JSON.stringify(result)}`);
  return JSON.parse(textItem.text);
}

class WereadClient {
  constructor(env, launchConfig = {}) {
    const command = launchConfig.command || "npx";
    const args = launchConfig.args?.length ? launchConfig.args : ["-y", "mcp-server-weread"];
    console.error(`[WeReadPipeline] launching weread MCP: ${command} ${args.join(" ")}`);
    this.child = spawn(command, args, {
      stdio: ["pipe", "pipe", "inherit"],
      env: { ...process.env, ...compactEnv(env) },
    });
    this.buffer = "";
    this.id = 0;
    this.pending = new Map();
    this.child.stdout.on("data", (chunk) => {
      this.buffer += chunk.toString();
      this.flush();
    });
  }

  flush() {
    while (true) {
      const idx = this.buffer.indexOf("\n");
      if (idx < 0) return;
      const line = this.buffer.slice(0, idx).trim();
      this.buffer = this.buffer.slice(idx + 1);
      if (!line) continue;
      let message;
      try {
        message = JSON.parse(line);
      } catch {
        continue;
      }
      const resolver = this.pending.get(message.id);
      if (resolver) {
        this.pending.delete(message.id);
        resolver(message);
      }
    }
  }

  send(method, params, { notification = false } = {}) {
    const payload = { jsonrpc: "2.0", method };
    if (!notification) payload.id = ++this.id;
    if (params !== undefined) payload.params = params;
    this.child.stdin.write(`${JSON.stringify(payload)}\n`);
    if (notification) return Promise.resolve(null);
    return new Promise((resolve) => this.pending.set(payload.id, resolve));
  }

  async initialize() {
    await this.send("initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: { name: "weread-flowus-pipeline", version: "0.1" },
    });
    await this.send("notifications/initialized", {}, { notification: true });
  }

  async callTool(name, args = {}) {
    const response = await this.send("tools/call", { name, arguments: args });
    const result = response.result;
    if (result.isError) throw new Error((result.content || []).map((item) => item.text || "").join("\n"));
    return parseToolText(result);
  }

  async close() {
    this.child.kill("SIGTERM");
  }
}

class FlowusClient {
  constructor(url) {
    this.url = new URL(url);
    this.sessionId = null;
    this.id = 0;
  }

  async request(method, params, { notification = false } = {}) {
    const payload = { jsonrpc: "2.0", method };
    if (!notification) payload.id = ++this.id;
    if (params !== undefined) payload.params = params;

    const body = JSON.stringify(payload);
    const transport = this.url.protocol === "https:" ? https : http;

    const responseText = await new Promise((resolve, reject) => {
      const req = transport.request(
        this.url,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Accept: "application/json, text/event-stream",
            ...(this.sessionId ? { "Mcp-Session-Id": this.sessionId } : {}),
          },
        },
        (res) => {
          let data = "";
          this.sessionId ||= res.headers["mcp-session-id"];
          res.on("data", (chunk) => {
            data += chunk.toString();
          });
          res.on("end", () => {
            if (res.statusCode >= 400) {
              reject(new Error(`HTTP ${res.statusCode}: ${data}`));
            } else {
              resolve(data);
            }
          });
        }
      );

      req.on("error", reject);
      req.write(body);
      req.end();
    });

    if (notification || !responseText.trim()) return null;
    const normalized =
      responseText.startsWith("event:") || responseText.startsWith("data:")
        ? responseText
            .split(/\r?\n/)
            .filter((line) => line.startsWith("data:"))
            .map((line) => line.replace(/^data:\s*/, ""))
            .join("")
        : responseText;
    return JSON.parse(normalized);
  }

  async initialize() {
    await this.request("initialize", {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: { name: "weread-flowus-pipeline", version: "0.1" },
    });
    await this.request("notifications/initialized", {}, { notification: true });
  }

  async callTool(name, args = {}) {
    const response = await this.request("tools/call", { name, arguments: args });
    if (!response || !response.result) {
      throw new Error(`FlowUS tool ${name} returned empty or malformed response: ${JSON.stringify(response)}`);
    }
    const result = response.result;
    if (result.isError) throw new Error((result.content || []).map((item) => item.text || "").join("\n"));
    if (result.structuredContent && Object.keys(result.structuredContent).length > 0) return result.structuredContent;
    return parseToolText(result);
  }
}

function extractBook(payload, title) {
  const books = payload.books || [];
  if (!books.length) {
    throw new Error(`No WeRead bookshelf match for ${title}`);
  }
  const exact = books.find((book) => book.title === title || book.title.startsWith(title));
  return exact || books[0];
}

function flattenHighlights(chapters) {
  const lines = [];
  for (const chapter of chapters || []) {
    const nodes = chapter.children?.length ? chapter.children : [chapter];
    for (const node of nodes) {
      const title = node.title || chapter.title;
      for (const item of node.highlights || []) {
        lines.push({ chapter: title, text: item.text });
      }
      for (const note of node.notes || []) {
        lines.push({ chapter: title, text: `笔记：${note.content}` });
      }
    }
  }
  return lines;
}

function summarizeBook(searchResult, notesResult) {
  const status = notesResult.reading_status || {};
  const phase = status.finish_reading || status.progress === 100 ? "完读入库" : "阶段性入库";
  const highlightLines = flattenHighlights(notesResult.chapters || []);
  const topHighlights = highlightLines.slice(0, 12);
  const chapterTitles = [...new Set(topHighlights.map((item) => item.chapter).filter(Boolean))].slice(0, 4);
  const themeTags = [
    ...(searchResult.categories || []),
    ...chapterTitles.map((title) =>
      title
        .replace(/^第[一二三四五六七八九十百千万0-9]+[章节部分]\s*/, "")
        .replace(/[：:].*$/, "")
        .trim()
    ),
  ]
    .filter(Boolean)
    .slice(0, 5);

  const summary = `${phase}：当前阅读进度 ${status.progress || 0}%，已拉取 ${notesResult.total_highlights || 0} 条划线和 ${
    notesResult.total_notes || 0
  } 条笔记，内容目前集中在 ${chapterTitles.join("、") || "前几章"}。`;

  const question =
    topHighlights.some((item) => item.text.includes("合作")) && topHighlights.some((item) => item.text.includes("秩序"))
      ? "想象秩序如何同时扩展大规模合作并制造新的压迫？"
      : `《${searchResult.title}》当前最值得继续追问的核心问题是什么？`;

  return {
    phase,
    summary,
    question,
    themeTags,
    topHighlights,
  };
}

function buildRawMarkdown(book, notesResult, synthesis) {
  const lines = flattenHighlights(notesResult.chapters || []);
  const excerptBlock = synthesis.topHighlights
    .map((item) => `- ${item.chapter}：${item.text}`)
    .join("\n");
  const chapterBlock = lines.map((item) => `- ${item.chapter}：${item.text}`).join("\n");
  return `# 《${book.title}》\n\n## 基本信息\n\n- 作者：${book.author || "未知"}\n- 译者：${book.translator || "无"}\n- 分类：${(book.categories || []).join(" / ") || "未提供"}\n- 微信读书进度：${notesResult.reading_status?.progress || 0}%\n- 划线：${notesResult.total_highlights || 0} 条\n- 笔记：${notesResult.total_notes || 0} 条\n\n## 一句话结论\n\n${synthesis.summary}\n\n## 我的核心摘录\n\n${excerptBlock || "- 暂无摘录"}\n\n## 分章节划线与笔记\n\n${chapterBlock || "- 暂无内容"}\n\n## 对知识库的影响\n\n- 本书已被处理为 ${synthesis.phase}。\n- 适合作为后续主题页或跨书比较的来源资料。\n\n## 待验证点\n\n- 如果当前进度不足 100%，本次结论应被视为阶段性理解。\n`;
}

function buildWikiMarkdown(book, notesResult, synthesis) {
  return `# 《${book.title}》\n\n## 这本书对我意味着什么\n\n${synthesis.summary}\n\n## 核心框架\n\n- 当前高频主题：${synthesis.themeTags.join("、") || "待提炼"}\n- 当前核心问题：${synthesis.question}\n\n## 支持依据\n\n${synthesis.topHighlights.map((item) => `- ${item.chapter}：${item.text}`).join("\n") || "- 待补充"}\n\n## 反对依据 / 争议\n\n- 如果本书未完读，不应把当前理解视为最终结论。\n- 如需更强结论，应补充完读后的后半部内容或跨书对照。\n\n## 对已有认知的更新\n\n- 本页由脚本自动生成第一版结构，后续应由 Agent 做更高质量的综合修订。\n\n## 更新记录\n\n- ${today()}: 通过 weread-to-flowus-pipeline 生成首版。当前阅读进度 ${notesResult.reading_status?.progress || 0}%。\n`;
}

function buildQuestionMarkdown(synthesis) {
  return `# ${synthesis.question}\n\n## 当前答案\n\n${synthesis.summary}\n\n## 支持依据\n\n- 当前答案主要基于本书的阶段性划线与笔记。\n\n## 不确定性\n\n- 这是一版自动生成的问题卡片，后续仍应人工复核和补充。\n`;
}

function buildLogMarkdown(book) {
  return `# 微信读书沉淀：《${book.title}》\n\n## 本次操作\n\n- 通过 WeRead MCP 拉取书籍元数据、划线和笔记\n- 通过 FlowUS MCP 批量创建数据库记录\n- 写入 Raw Source、Wiki Page、Question 与 Log，并完成关系回连\n\n## 后续动作\n\n- 完读后复查并决定是否拆出独立主题页\n`;
}

function today() {
  return new Date().toISOString().slice(0, 10);
}

async function batchCreatePage(flowus, databaseId, titleProperty, title) {
  const body = {
    operations: [
      {
        id: "create_record",
        route: "POST /v2/pages",
        body: {
          parent: { database_id: databaseId },
          properties: {
            [titleProperty]: titleValue(title),
          },
        },
      },
    ],
  };
  const result = await flowus.callTool("API-batch", { body: JSON.stringify(body) });
  const row = (result.results || []).find((item) => item.id === "create_record");
  if (!row || row.status >= 400) {
    throw new Error(`Batch create failed for ${title}: ${JSON.stringify(row || result)}`);
  }
  return row.body;
}

async function verifyRecord(flowus, databaseId, titleProperty, title) {
  return flowus.callTool("API-queryDatabase", {
    database_id: databaseId,
    body: JSON.stringify({
      filter: {
        property: titleProperty,
        title: { equals: title },
      },
      page_size: 5,
    }),
  });
}

async function ingestBook(title, { apply = false } = {}) {
  const configText = readFile(CONFIG_PATH);
  const integrationIds = parseIntegrationIds(readFile(INTEGRATION_PATH));
  const wereadBlock = extractTomlBlock(configText, "mcp_servers.weread");
  const wereadEnv = {
    CC_URL: extractValue(configText, "CC_URL"),
    CC_ID: extractValue(configText, "CC_ID"),
    CC_PASSWORD: extractValue(configText, "CC_PASSWORD"),
    WEREAD_COOKIE: extractValue(configText, "WEREAD_COOKIE"),
  };
  const wereadLaunch = {
    command: extractValue(wereadBlock, "command"),
    args: extractArrayValue(wereadBlock, "args"),
  };

  const weread = new WereadClient(wereadEnv, wereadLaunch);
  await weread.initialize();
  let searchPayload;
  let book;
  let notesResult;
  try {
    searchPayload = await weread.callTool("search_books", {
      keyword: title,
      max_results: 5,
      include_details: true,
    });
    book = extractBook(searchPayload, title);
    notesResult = await weread.callTool("get_book_notes_and_highlights", {
      book_id: book.book_id,
      include_chapters: true,
      organize_by_chapter: true,
    });
  } catch (error) {
    const message = String(error.message || error);
    if (message.includes("401")) {
      throw new Error(
        "WeRead notebook fetch returned 401. Refresh CookieCloud or WEREAD_COOKIE first, then rerun the pipeline."
      );
    }
    throw error;
  } finally {
    await weread.close();
  }

  const synthesis = summarizeBook(book, notesResult);
  const bundle = {
    requested_title: title,
    matched_book: book,
    notes: {
      total_highlights: notesResult.total_highlights,
      total_notes: notesResult.total_notes,
      progress: notesResult.reading_status?.progress || 0,
    },
    synthesis,
  };

  if (!apply) {
    return { mode: "dry-run", bundle };
  }

  const flowusUrl = extractValue(configText, "url");
  if (!flowusUrl) throw new Error("FlowUS MCP url not found in ~/.codex/config.toml");

  const flowus = new FlowusClient(flowusUrl);
  await flowus.initialize();

  const rawTitle = book.title;
  const wikiTitle = `《${book.title}》`;
  const questionTitle = synthesis.question;
  const logTitle = `微信读书沉淀：《${book.title.replace(/^《|》$/g, "")}》`;

  const rawPage = await batchCreatePage(flowus, integrationIds.raw_sources, "标题", rawTitle);
  const wikiPage = await batchCreatePage(flowus, integrationIds.wiki_pages, "页面名称", wikiTitle);
  const questionPage = await batchCreatePage(flowus, integrationIds.questions, "问题", questionTitle);
  const logPage = await batchCreatePage(flowus, integrationIds.log, "标题", logTitle);

  await flowus.callTool("API-updatePage", {
    page_id: rawPage.id,
    body: JSON.stringify({
      properties: {
        类型: selectValue("书"),
        作者: richTextValue(
          [book.author, book.translator ? `${book.translator} 译` : null].filter(Boolean).join("；")
        ),
        收集日期: dateValue(today()),
        处理状态: selectValue("已入库"),
        主题标签: multiSelectValue(synthesis.themeTags),
        可信度: selectValue("中"),
        重要性: numberValue(4),
        摘要: richTextValue(synthesis.summary),
        关键摘录: richTextValue(
          synthesis.topHighlights
            .slice(0, 4)
            .map((item) => `${item.chapter}：${item.text}`)
            .join("；")
        ),
      },
    }),
  });

  await flowus.callTool("API-updatePage", {
    page_id: rawPage.id,
    body: JSON.stringify({
      properties: {
        "关联 Wiki Pages": relationValue([wikiPage.id]),
        "关联 Questions": relationValue([questionPage.id]),
        处理记录: richTextValue(
          `通过 weread_flowus_pipeline.js 自动处理 ${synthesis.phase}，并使用 FlowUS API-batch 创建正式数据库记录。`
        ),
        最后处理时间: dateValue(today()),
      },
    }),
  });

  await flowus.callTool("API-updatePage", {
    page_id: wikiPage.id,
    body: JSON.stringify({
      properties: {
        页面类型: selectValue("主题"),
        一句话摘要: richTextValue(
          `${book.title} 当前最值得保留的洞见，是 ${synthesis.question.replace(/[？?]$/, "")} 这条主线。`
        ),
        成熟度: selectValue("草稿"),
        可信度: selectValue("待验证"),
        领域: multiSelectValue(["历史", "人文"]),
        主题标签: multiSelectValue(synthesis.themeTags),
        相关资料: relationValue([rawPage.id]),
        相关问题: relationValue([questionPage.id]),
        最后更新: dateValue(today()),
        推荐复查时间: dateValue(today()),
        待验证点: richTextValue("如果当前进度不足 100%，本页只代表阶段性理解，完读后必须复查。"),
        更新摘要: richTextValue(`由脚本自动生成第一版书籍页，当前进度 ${notesResult.reading_status?.progress || 0}%。`),
      },
    }),
  });

  await flowus.callTool("API-updatePage", {
    page_id: questionPage.id,
    body: JSON.stringify({
      properties: {
        状态: selectValue("探索中"),
        问题类型: selectValue("研究"),
        优先级: selectValue("高"),
        当前答案: richTextValue(synthesis.summary),
        相关资料: relationValue([rawPage.id]),
        相关知识页: relationValue([wikiPage.id]),
        下一个问题: richTextValue("完读后复查，并和其他同主题书籍做对照。"),
      },
    }),
  });

  await flowus.callTool("API-updatePage", {
    page_id: questionPage.id,
    body: JSON.stringify({
      properties: {
        "是否沉淀为 Wiki": checkboxValue(true),
        创建日期: dateValue(today()),
        最后更新: dateValue(today()),
      },
    }),
  });

  await flowus.callTool("API-updatePage", {
    page_id: logPage.id,
    body: JSON.stringify({
      properties: {
        时间: dateValue(today()),
        操作类型: selectValue("ingest"),
        涉及资料: relationValue([rawPage.id]),
        涉及知识页: relationValue([wikiPage.id]),
        涉及问题: relationValue([questionPage.id]),
        主要变化: richTextValue(`自动处理《${book.title}》并写入四类正式记录。`),
        后续动作: richTextValue("完读后复查，并考虑拆出独立主题页。"),
        操作者: selectValue("我+LLM"),
      },
    }),
  });

  await flowus.callTool("API-putMarkdown", {
    page_id: rawPage.id,
    body: JSON.stringify({ markdown: buildRawMarkdown(book, notesResult, synthesis) }),
  });
  await flowus.callTool("API-putMarkdown", {
    page_id: wikiPage.id,
    body: JSON.stringify({ markdown: buildWikiMarkdown(book, notesResult, synthesis) }),
  });
  await flowus.callTool("API-putMarkdown", {
    page_id: questionPage.id,
    body: JSON.stringify({ markdown: buildQuestionMarkdown(synthesis) }),
  });
  await flowus.callTool("API-putMarkdown", {
    page_id: logPage.id,
    body: JSON.stringify({ markdown: buildLogMarkdown(book) }),
  });

  const verification = {
    raw: await verifyRecord(flowus, integrationIds.raw_sources, "标题", rawTitle),
    wiki: await verifyRecord(flowus, integrationIds.wiki_pages, "页面名称", wikiTitle),
    question: await verifyRecord(flowus, integrationIds.questions, "问题", questionTitle),
    log: await verifyRecord(flowus, integrationIds.log, "标题", logTitle),
  };

  return {
    mode: "apply",
    bundle,
    created: {
      raw_id: rawPage.id,
      wiki_id: wikiPage.id,
      question_id: questionPage.id,
      log_id: logPage.id,
    },
    verification,
  };
}

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (token.startsWith("--")) {
      const key = token.slice(2);
      const next = argv[i + 1];
      if (!next || next.startsWith("--")) {
        args[key] = true;
      } else {
        args[key] = next;
        i += 1;
      }
    } else {
      args._.push(token);
    }
  }
  return args;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const command = args._[0];

  if (!command || args.help) {
    console.log(
      [
        "Usage:",
        "  node scripts/weread_flowus_pipeline.js ingest --title \"书名\" [--apply]",
        "",
        "Default mode is dry-run. Add --apply to write records into FlowUS.",
      ].join("\n")
    );
    process.exit(0);
  }

  if (command !== "ingest") {
    throw new Error(`Unsupported command: ${command}`);
  }

  if (!args.title) {
    throw new Error("Missing required --title");
  }

  const result = await ingestBook(args.title, { apply: Boolean(args.apply) });
  console.log(JSON.stringify(result, null, 2));
}

main().catch((error) => {
  console.error(error.message || String(error));
  process.exit(1);
});
