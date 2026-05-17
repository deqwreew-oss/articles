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

  const SETTINGS_KEY = "site:settings";

  function loadSettings() {
    try {
      const raw = localStorage.getItem(SETTINGS_KEY);
      return raw ? JSON.parse(raw) : {};
    } catch (err) {
      return {};
    }
  }

  function saveSettings(state) {
    try {
      localStorage.setItem(SETTINGS_KEY, JSON.stringify(state));
    } catch (err) {
      // ignore quota / privacy mode errors
    }
  }

  function applyTheme(dark) {
    document.documentElement.setAttribute("data-theme", dark ? "dark" : "light");
  }

  function applyGrain(off) {
    document.body.classList.toggle("no-grain", !!off);
  }

  function prefersDark() {
    return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
  }

  function renderSettings() {
    const header = document.querySelector(".header");

    if (!header || header.querySelector(".settings")) {
      return;
    }

    const state = loadSettings();
    const dark = state.theme ? state.theme === "dark" : prefersDark();
    const grainOn = state.grain === "on";

    applyTheme(dark);
    applyGrain(!grainOn);

    const checkSvg = '<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="3.5,8.5 6.5,11.5 12.5,4.5"/></svg>';

    const wrap = document.createElement("div");
    wrap.className = "settings";
    wrap.innerHTML = `
      <button class="settings-btn" type="button" aria-label="Настройки" aria-expanded="false" aria-haspopup="menu">
        <svg viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
          <circle cx="4" cy="10" r="1.6"/>
          <circle cx="10" cy="10" r="1.6"/>
          <circle cx="16" cy="10" r="1.6"/>
        </svg>
      </button>
      <div class="settings-menu" role="menu" data-open="false">
        <button class="settings-item" type="button" role="menuitemcheckbox" data-setting="theme" aria-checked="${dark}">
          <span class="settings-check">${checkSvg}</span>
          <span>Тёмная тема</span>
        </button>
        <button class="settings-item" type="button" role="menuitemcheckbox" data-setting="grain" aria-checked="${grainOn}">
          <span class="settings-check">${checkSvg}</span>
          <span>Зернистость</span>
        </button>
      </div>
    `;

    header.appendChild(wrap);

    const btn = wrap.querySelector(".settings-btn");
    const menu = wrap.querySelector(".settings-menu");
    const items = wrap.querySelectorAll(".settings-item");

    function setOpen(open) {
      btn.setAttribute("aria-expanded", String(open));
      menu.setAttribute("data-open", String(open));
    }

    btn.addEventListener("click", (event) => {
      event.stopPropagation();
      const open = menu.getAttribute("data-open") === "true";
      setOpen(!open);
    });

    document.addEventListener("click", (event) => {
      if (!wrap.contains(event.target)) {
        setOpen(false);
      }
    });

    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape") {
        setOpen(false);
      }
    });

    items.forEach((item) => {
      item.addEventListener("click", (event) => {
        event.stopPropagation();
        const key = item.dataset.setting;
        const current = loadSettings();

        if (key === "theme") {
          const nextDark = item.getAttribute("aria-checked") !== "true";
          current.theme = nextDark ? "dark" : "light";
          applyTheme(nextDark);
          item.setAttribute("aria-checked", String(nextDark));
        } else if (key === "grain") {
          const nextOn = item.getAttribute("aria-checked") !== "true";
          current.grain = nextOn ? "on" : "off";
          applyGrain(!nextOn);
          item.setAttribute("aria-checked", String(nextOn));
        }

        saveSettings(current);
      });
    });
  }

  function renderCopyButtons() {
    const blocks = document.querySelectorAll(".article-body details.code-block");

    if (!blocks.length) {
      return;
    }

    const copySvg = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>';
    const checkSvg = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"/></svg>';

    blocks.forEach((block) => {
      if (block.querySelector(".code-copy-btn")) {
        return;
      }

      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "code-copy-btn";
      btn.setAttribute("aria-label", "Копировать");
      btn.innerHTML = copySvg;

      btn.addEventListener("click", (event) => {
        event.stopPropagation();
        const pre = block.querySelector("pre");

        if (!pre) {
          return;
        }

        const text = pre.textContent || "";
        navigator.clipboard.writeText(text).then(() => {
          btn.innerHTML = checkSvg;
          btn.classList.add("copied");

          setTimeout(() => {
            btn.innerHTML = copySvg;
            btn.classList.remove("copied");
          }, 1500);
        });
      });

      block.appendChild(btn);
    });
  }

  renderNav();
  renderCards();
  renderCopyButtons();
  renderSettings();
})();
