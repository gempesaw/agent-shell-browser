globalThis.agentShellBrowserExtract = (mode) => {
  const turndown = new TurndownService({
    headingStyle: "atx",
    codeBlockStyle: "fenced",
    bulletListMarker: "-",
  });
  turndown.remove(["script", "style", "noscript", "template"]);

  const absolutize = (root) => {
    for (const a of root.querySelectorAll("a[href]")) a.setAttribute("href", a.href);
    for (const img of root.querySelectorAll("img[src]")) img.setAttribute("src", img.src);
    return root;
  };

  const selection = () => {
    const sel = getSelection();
    if (!sel || sel.isCollapsed || sel.rangeCount === 0) return null;

    const container = document.createElement("div");
    for (let i = 0; i < sel.rangeCount; i++) {
      container.appendChild(sel.getRangeAt(i).cloneContents());
    }

    const markdown = turndown.turndown(absolutize(container)).trim();
    return { kind: "selection", content: markdown || sel.toString().trim() };
  };

  const page = () => {
    const article = new Readability(document.cloneNode(true)).parse();
    if (article?.content) {
      return {
        kind: "page",
        title: article.title || document.title,
        content: turndown.turndown(article.content).trim(),
      };
    }

    const body = absolutize(document.body.cloneNode(true));
    return { kind: "page", content: turndown.turndown(body).trim() };
  };

  if (mode === "selection") return selection();
  if (mode === "page") return page();
  return selection() ?? page();
};
