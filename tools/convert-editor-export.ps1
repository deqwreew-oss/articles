<#
.SYNOPSIS
  Конвертирует HTML, экспортированный редактором, в каноничный формат сайта.

.DESCRIPTION
  - Вытаскивает все inline base64-картинки в assets/<slug>/img-NN.<ext>
  - Заменяет относительные пути ../ на ../../ (структура posts/<slug>/index.html)
  - Снимает блок <span class="card-tag">...</span>
  - Меняет <section class="placeholder article-stage"> на <article ...>
  - Чистит мусорные <br><br>...</p> в конце статьи
  - Вставляет meta-блок (description, og, twitter, canonical)
  - Подставляет в конец body скрипты articles-data.js, site.js и встроенный
    скрипт улучшения карусели + lazy-load картинок

.PARAMETER InputFile
  Абсолютный путь к HTML-файлу от редактора.

.PARAMETER Slug
  Имя папки в posts/ и assets/.

.PARAMETER Description
  Текст meta description.

.PARAMETER OgTitle
  Короткий заголовок для og:title / twitter:title.

.PARAMETER OgDescription
  Короткий лид для og:description / twitter:description.

.PARAMETER CoverPath
  Путь к обложке относительно корня сайта (например assets/<slug>-cover.jpg).

.PARAMETER Domain
  Базовый домен сайта (по умолчанию https://some-one.bond).

.PARAMETER Force
  Очистить папку assets/<slug>/ перед записью.

.EXAMPLE
  pwsh -File tools/convert-editor-export.ps1 `
    -InputFile 'C:\Users\...\article (24).html' `
    -Slug 'nano-banana-pro-bypass' `
    -Description 'Снял промежуточный слой Gemini 3 Pro Image.' `
    -OgTitle 'Полный обход Nano Banana Pro' `
    -OgDescription 'Снял промежуточный слой Gemini 3 Pro Image и посмотрел, что делает базовая модель без обёртки.' `
    -CoverPath 'assets/nano-banana-pro-cover.jpg' `
    -Force
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$InputFile,
  [Parameter(Mandatory)][string]$Slug,
  [Parameter(Mandatory)][string]$Description,
  [Parameter(Mandatory)][string]$OgTitle,
  [Parameter(Mandatory)][string]$OgDescription,
  [Parameter(Mandatory)][string]$CoverPath,
  [string]$Domain = 'https://some-one.bond',
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$postsDir = Join-Path $repoRoot ("posts/" + $Slug)
$assetsDir = Join-Path $repoRoot ("assets/" + $Slug)
$outFile = Join-Path $postsDir 'index.html'

if (-not (Test-Path $InputFile)) {
  throw "Input file not found: $InputFile"
}

New-Item -ItemType Directory -Force -Path $postsDir | Out-Null
if ($Force -and (Test-Path $assetsDir)) {
  Get-ChildItem -Path $assetsDir -File | Remove-Item -Force
}
New-Item -ItemType Directory -Force -Path $assetsDir | Out-Null

Write-Host "Reading $InputFile" -ForegroundColor Cyan
$html = [System.IO.File]::ReadAllText($InputFile, [System.Text.UTF8Encoding]::new($false))

# 1. Extract inline base64 images and replace with relative paths
$imgPattern = 'data:image/(?<ext>png|jpe?g|gif|webp);base64,(?<data>[A-Za-z0-9+/=]+)'
$imgMatches = [regex]::Matches($html, $imgPattern)
Write-Host ("Found {0} inline images" -f $imgMatches.Count) -ForegroundColor Cyan

$replacements = New-Object System.Collections.Generic.List[object]
$counter = 1
foreach ($m in $imgMatches) {
  $ext = $m.Groups['ext'].Value.ToLower()
  if ($ext -eq 'jpeg') { $ext = 'jpg' }
  $name = "image-{0:D2}.{1}" -f $counter, $ext
  $outPath = Join-Path $assetsDir $name
  $bytes = [Convert]::FromBase64String($m.Groups['data'].Value)
  [System.IO.File]::WriteAllBytes($outPath, $bytes)
  $replacements.Add([pscustomobject]@{
    Index = $m.Index
    Length = $m.Length
    Replace = "../../assets/$Slug/$name"
  })
  $counter++
}

# Apply replacements from end to start to preserve offsets
$sb = New-Object System.Text.StringBuilder
[void]$sb.Append($html)
foreach ($r in ($replacements | Sort-Object Index -Descending)) {
  [void]$sb.Remove($r.Index, $r.Length)
  [void]$sb.Insert($r.Index, $r.Replace)
}
$html = $sb.ToString()

# 2. Stylesheet path: ../styles.css -> ../../styles.css
$html = [regex]::Replace($html, 'href="\.\./styles\.css"', 'href="../../styles.css"')

# 3. Nav: data-site-root + Home href
$html = [regex]::Replace($html,
  '<nav class="nav" aria-label="Main" data-site-nav data-nav-mode="article">',
  '<nav class="nav" aria-label="Main" data-site-nav data-nav-mode="article" data-site-root="../../">')
$html = [regex]::Replace($html, 'class="nav-link" href="\.\./index\.html"', 'class="nav-link" href="../../index.html"')

# 4. Article-stage section -> article
$html = [regex]::Replace($html, '<section class="placeholder article-stage">', '<article class="placeholder article-stage">')
$html = [regex]::Replace($html, '</section>(\s*</main>)', '</article>$1')

# 5. Remove card-tag span (with surrounding whitespace)
$html = [regex]::Replace($html, '\s*<span class="card-tag">[^<]*</span>', '')

# 6. Strip trailing <br>...</p>
$html = [regex]::Replace($html, '(?:<br\s*/?>\s*)+(</p>)', '$1')

# 7. Script src paths: ../articles-data.js -> ../../articles-data.js, ../site.js -> ../../site.js
$html = [regex]::Replace($html, 'src="\.\./articles-data\.js"', 'src="../../articles-data.js"')
$html = [regex]::Replace($html, 'src="\.\./site\.js"', 'src="../../site.js"')

# 7.1. Keep article body width controlled by styles.css, not editor inline styles.
$html = [regex]::Replace(
  $html,
  '<div class="article-body"\s+style="max-width:[^"]*?margin-inline:auto;">',
  '<div class="article-body">'
)

# 8. Inject meta tags after </title>
function Encode-Attr {
  param([string]$value)
  if ($null -eq $value) { return '' }
  return $value.Replace('&','&amp;').Replace('"','&quot;').Replace('<','&lt;').Replace('>','&gt;')
}
$descEsc = Encode-Attr $Description
$ogTitleEsc = Encode-Attr $OgTitle
$ogDescEsc = Encode-Attr $OgDescription
$canonical = "$Domain/posts/$Slug/"
$coverUrl = "$Domain/$CoverPath"

$metaBlock = @"
  <meta name="description" content="$descEsc">
  <meta property="og:type" content="article">
  <meta property="og:title" content="$ogTitleEsc">
  <meta property="og:description" content="$ogDescEsc">
  <link rel="canonical" href="$canonical">
  <meta property="og:url" content="$canonical">
  <meta property="og:image" content="$coverUrl">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="$ogTitleEsc">
  <meta name="twitter:description" content="$ogDescEsc">
  <meta name="twitter:image" content="$coverUrl">
"@

if ($html -notmatch 'name="description"') {
  $html = [regex]::Replace($html, '(</title>)', "`$1`r`n$metaBlock", 1)
}

# 9. Carousel + lazy-image runtime script
$runtimeScript = @'
  <script src="../../articles-data.js"></script>
  <script src="../../site.js"></script>
  <script>
  (() => {
    const PREV = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>';
    const NEXT = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>';

    const prepareImages = () => {
      const images = Array.from(document.querySelectorAll(".article-body img"));

      images.forEach((image, index) => {
        image.setAttribute("decoding", "async");

        if (index === 0) {
          image.setAttribute("loading", "eager");
          image.setAttribute("fetchpriority", "high");
          return;
        }

        image.setAttribute("loading", "lazy");
        image.setAttribute("fetchpriority", "low");
      });

      if (!("IntersectionObserver" in window)) {
        return;
      }

      const observer = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) {
            return;
          }

          const image = entry.target;
          image.setAttribute("loading", "eager");
          image.setAttribute("fetchpriority", "auto");
          observer.unobserve(image);
        });
      }, {
        rootMargin: "900px 0px",
        threshold: 0.01
      });

      images.slice(1).forEach((image) => observer.observe(image));
    };

    const getSlides = (track) => {
      const slides = track.querySelectorAll(":scope > .carousel-slide");
      return slides.length ? slides : track.querySelectorAll(":scope > img");
    };

    const enhance = (figure) => {
      if (figure.dataset.enh === "1") {
        return;
      }

      const track = figure.querySelector(".carousel-track");

      if (!track) {
        return;
      }

      const slides = getSlides(track);

      if (slides.length <= 1) {
        return;
      }

      figure.dataset.enh = "1";

      const prev = document.createElement("button");
      prev.type = "button";
      prev.className = "carousel-btn carousel-prev";
      prev.setAttribute("aria-label", "Назад");
      prev.innerHTML = PREV;

      const next = document.createElement("button");
      next.type = "button";
      next.className = "carousel-btn carousel-next";
      next.setAttribute("aria-label", "Вперёд");
      next.innerHTML = NEXT;

      const counter = document.createElement("div");
      counter.className = "carousel-counter";

      const getSlideWidth = () => {
        const [first] = getSlides(track);
        return first ? first.getBoundingClientRect().width : track.clientWidth;
      };

      const scroll = (direction) => {
        track.scrollBy({
          left: direction * getSlideWidth(),
          behavior: "smooth"
        });
      };

      const update = () => {
        const list = getSlides(track);

        if (!list.length) {
          counter.textContent = "";
          return;
        }

        const trackRect = track.getBoundingClientRect();
        let index = 0;
        let minDistance = Infinity;

        list.forEach((slide, slideIndex) => {
          const rect = slide.getBoundingClientRect();
          const distance = Math.abs(rect.left - trackRect.left);

          if (distance < minDistance) {
            minDistance = distance;
            index = slideIndex;
          }
        });

        counter.textContent = `${index + 1} / ${list.length}`;
      };

      let updateFrame = 0;
      const scheduleUpdate = () => {
        if (updateFrame) {
          return;
        }

        updateFrame = requestAnimationFrame(() => {
          updateFrame = 0;
          update();
        });
      };

      prev.addEventListener("click", (event) => {
        event.preventDefault();
        scroll(-1);
      });

      next.addEventListener("click", (event) => {
        event.preventDefault();
        scroll(1);
      });

      track.addEventListener("scroll", scheduleUpdate, { passive: true });
      window.addEventListener("resize", scheduleUpdate);

      figure.append(prev, next, counter);
      update();
    };

    const run = () => {
      prepareImages();
      document.querySelectorAll("figure.carousel").forEach(enhance);
    };

    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", run, { once: true });
    } else {
      run();
    }
  })();</script>
'@

# Remove old generic/runtime script tags that came from the editor (if duplicate)
$html = [regex]::Replace($html, '\s*<script>\s*\(\(\) => \{\s*const PREV =[\s\S]*?\}\)\(\);</script>', '')
$html = [regex]::Replace($html, '\s*<script src="\.\./\.\./articles-data\.js"></script>', '')
$html = [regex]::Replace($html, '\s*<script src="\.\./\.\./site\.js"></script>', '')

# Inject before </body>
$html = [regex]::Replace($html, '</body>', "$runtimeScript`r`n</body>", 1)

# Final: write
[System.IO.File]::WriteAllText($outFile, $html, [System.Text.UTF8Encoding]::new($false))

$outSize = [math]::Round((Get-Item $outFile).Length / 1KB, 1)
Write-Host ("Wrote {0} ({1} KB)" -f $outFile, $outSize) -ForegroundColor Green
Write-Host ("Wrote {0} images to {1}" -f $imgMatches.Count, $assetsDir) -ForegroundColor Green
