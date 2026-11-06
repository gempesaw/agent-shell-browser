const api = globalThis.browser ?? globalThis.chrome;

const MENUS = [
  { id: "send-selection", title: "Send selection to agent-shell…", contexts: ["selection"] },
  { id: "send-page", title: "Send page to agent-shell…", contexts: ["page"] },
];

async function createMenus() {
  await api.contextMenus.removeAll();
  for (const menu of MENUS) {
    api.contextMenus.create(menu);
  }
}

api.runtime.onInstalled.addListener(createMenus);
api.runtime.onStartup.addListener(createMenus);

async function extract(tabId, frameId, mode) {
  const target = { tabId, frameIds: [frameId ?? 0] };
  await api.scripting.executeScript({
    target,
    files: ["vendor/turndown.js", "vendor/Readability.js", "extract.js"],
  });

  const [result] = await api.scripting.executeScript({
    target,
    func: (m) => globalThis.agentShellBrowserExtract(m),
    args: [mode],
  });
  return result?.result;
}

async function openPicker(payload) {
  const id = crypto.randomUUID();
  await api.storage.session.set({ [id]: payload });
  await api.windows.create({
    url: api.runtime.getURL(`picker.html#${id}`),
    type: "popup",
    width: 720,
    height: 640,
  });
}

async function send(tab, frameId, mode, selectionText) {
  let payload;
  try {
    payload = await extract(tab.id, frameId, mode);
  } catch (e) {
    console.warn("agent-shell-browser: extraction failed", e);
  }

  if (!payload?.content && selectionText) {
    payload = { kind: "selection", content: selectionText };
  }
  if (!payload?.content) {
    payload = { kind: "page", content: "", error: "Could not read this page." };
  }

  await openPicker({ url: tab.url, title: tab.title, ...payload });
}

api.contextMenus.onClicked.addListener((info, tab) => {
  const mode = info.menuItemId === "send-selection" ? "selection" : "page";
  send(tab, info.frameId, mode, info.selectionText);
});

api.action.onClicked.addListener((tab) => {
  send(tab, 0, "auto");
});
