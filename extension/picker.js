const api = globalThis.browser ?? globalThis.chrome;
const HOST = "agent_shell_browser";

const $ = (id) => document.getElementById(id);
const payloadId = location.hash.slice(1);

let payload;
let sessions = [];
let visible = [];
let selected = 0;

function native(message) {
  return api.runtime.sendNativeMessage(HOST, message);
}

function showStatus(text, isError = false) {
  $("status").textContent = text;
  $("status").className = isError ? "error" : "";
}

function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text) node.textContent = text;
  return node;
}

function render() {
  const query = $("filter").value.trim().toLowerCase();
  visible = sessions.filter((s) =>
    [s.title, s.description, s.detail, s.cwd].join(" ").toLowerCase().includes(query)
  );
  selected = Math.max(0, Math.min(selected, visible.length - 1));

  const list = $("sessions");
  list.replaceChildren();
  visible.forEach((session, i) => {
    const item = el("li", i === selected ? "selected" : "");
    const head = el("div");
    head.append(el("span", "title", session.title));
    if (session.busy) head.append(el("span", "busy", "busy"));
    item.append(head);
    if (session.description) item.append(el("div", "description", session.description));
    if (session.detail) item.append(el("div", "detail", session.detail));
    item.append(el("div", "cwd", session.cwd));

    item.addEventListener("click", () => { selected = i; render(); });
    item.addEventListener("dblclick", () => { selected = i; deliver(false); });
    list.append(item);
  });

  list.children[selected]?.scrollIntoView({ block: "nearest" });
}

function move(delta) {
  if (!visible.length) return;
  selected = (selected + delta + visible.length) % visible.length;
  render();
}

async function deliver(submit) {
  const session = visible[selected];
  if (!session) return;

  showStatus(submit ? "Sending…" : "Staging…");
  const response = await native({
    action: "send",
    session: session.id,
    submit,
    instruction: $("instruction").value,
    kind: payload.kind,
    url: payload.url,
    title: payload.title,
    content: $("content").value,
  }).catch((e) => ({ ok: false, error: e.message }));

  if (!response?.ok) {
    showStatus(response?.error ?? "No response from Emacs", true);
    return;
  }

  await api.storage.session.remove(payloadId);
  window.close();
}

document.addEventListener("keydown", (e) => {
  const mod = e.metaKey || e.ctrlKey;
  const inTextarea = e.target.tagName === "TEXTAREA";

  if (e.key === "Escape") {
    window.close();
  } else if (e.key === "Enter" && mod) {
    e.preventDefault();
    deliver(e.shiftKey);
  } else if (e.key === "Enter" && !inTextarea) {
    e.preventDefault();
    deliver(false);
  } else if ((e.ctrlKey && e.key === "n") || (!inTextarea && e.key === "ArrowDown")) {
    e.preventDefault();
    move(1);
  } else if ((e.ctrlKey && e.key === "p") || (!inTextarea && e.key === "ArrowUp")) {
    e.preventDefault();
    move(-1);
  }
});

$("filter").addEventListener("input", () => { selected = 0; render(); });
$("stage").addEventListener("click", () => deliver(false));
$("submit").addEventListener("click", () => deliver(true));

async function init() {
  payload = (await api.storage.session.get(payloadId))[payloadId];
  if (!payload) {
    showStatus("Nothing to send; this picker has expired.", true);
    return;
  }

  $("source").textContent = `${payload.kind === "selection" ? "Selection" : "Page"}: ${payload.title || payload.url}`;
  $("content").value = payload.content;
  $("content-summary").textContent = `${payload.content.length.toLocaleString()} characters (edit)`;
  if (payload.error) showStatus(payload.error, true);
  $("instruction").focus();

  const response = await native({ action: "list" }).catch((e) => ({ ok: false, error: e.message }));
  if (!response?.ok) {
    showStatus(response?.error ?? "No response from Emacs", true);
    return;
  }

  sessions = response.sessions;
  if (!sessions.length) showStatus("No agent-shell sessions running.", true);
  render();
}

init();
