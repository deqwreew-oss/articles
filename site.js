(() => {
  "use strict";

  const articles = Array.isArray(window.ARTICLES) ? window.ARTICLES : [];

  function escapeHtml(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function normalizePath(value) {
    return String(value || "")
      .replace(/^\.\//, "")
      .replace(/\/index\.html$/i, "/")
      .replace(/\\/g, "/");
  }

  function getCurrentPath() {
    const path = decodeURIComponent(window.location.pathname || "");
    const parts = path.split("/");
    const file = parts[parts.length - 1] || "index.html";
    const folder = parts.slice(-2).join("/");

    return {
      file,
      folder,
      full: normalizePath(path)
    };
  }

  function isCurrentArticle(article) {
    const current = getCurrentPath();
    const articleUrl = normalizePath(article.url);

    return current.full.endsWith(articleUrl) ||
      current.folder === articleUrl ||
      current.file === articleUrl.split("/").pop();
  }

  function buildHref(article, mode, root) {
    const url = normalizePath(article.url);

    if (mode === "article") {
      return `${root}${url}`;
    }

    return `./${url}`;
  }

  function renderNav() {
    const nav = document.querySelector("[data-site-nav]");

    if (!nav) {
      return;
    }

    const mode = nav.dataset.navMode || "home";
    const root = nav.dataset.siteRoot || (mode === "article" ? "../" : "./");
    const homeHref = mode === "article" ? `${root}index.html` : "./index.html";
    const links = [
      mode === "home"
        ? '<a class="nav-link" aria-current="page">Home</a>'
        : `<a class="nav-link" href="${homeHref}">Home</a>`
    ];

    articles.forEach((article) => {
      const current = mode === "article" && isCurrentArticle(article);
      const title = escapeHtml(article.navTitle || article.title);

      links.push(current
        ? `<a class="nav-link" aria-current="page">${title}</a>`
        : `<a class="nav-link" href="${escapeHtml(buildHref(article, mode, root))}">${title}</a>`
      );
    });

    nav.innerHTML = links.join("");
  }

  function renderCards() {
    const list = document.querySelector("[data-articles-list]");
    const count = document.querySelector("[data-articles-count]");

    if (count) {
      count.textContent = String(articles.length);
    }

    if (!list) {
      return;
    }

    list.innerHTML = articles.map((article) => `
      <a href="${escapeHtml(buildHref(article, "home"))}" class="card">
        <div class="card-meta">
          <span class="card-tag">${escapeHtml(article.category)}</span>
          <span class="card-meta-info">
            <span class="card-date">${escapeHtml(article.date)}</span>
            <span class="card-dot" aria-hidden="true">·</span>
            <span class="card-readtime">${escapeHtml(article.readTime)}</span>
          </span>
        </div>
        <h3 class="card-title">${escapeHtml(article.title)}</h3>
        <p class="card-desc">${escapeHtml(article.description)}</p>
        <span class="card-cta">
          <span class="card-cta-label">Читать</span>
          <svg class="card-cta-icon" viewBox="0 0 20 20" width="15" height="15" fill="currentColor" aria-hidden="true">
            <path fill-rule="evenodd" d="M3 10a.75.75 0 0 1 .75-.75h10.638L10.23 5.29a.75.75 0 1 1 1.04-1.08l5.5 5.25a.75.75 0 0 1 0 1.08l-5.5 5.25a.75.75 0 1 1-1.04-1.08l4.158-3.96H3.75A.75.75 0 0 1 3 10Z" clip-rule="evenodd"/>
          </svg>
        </span>
      </a>
    `).join("");
  }

  renderNav();
  renderCards();
})();
