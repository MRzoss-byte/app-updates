const list = document.querySelector("#apps");

function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text != null) node.textContent = text;
  return node;
}

function formatWhen(iso) {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return iso;
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(date);
}

function feedLink(appId) {
  const link = el("a", "feed", `/${appId}/latest.json`);
  link.href = `/${appId}/latest.json`;
  return link;
}

async function renderApp(app) {
  const card = el("article", "card");
  card.id = app.id;
  card.append(el("h2", null, app.name));
  if (app.packageName) card.append(el("p", "package", app.packageName));

  let latest = null;
  let failed = false;
  try {
    const response = await fetch(`/${app.id}/latest.json`, { cache: "no-cache" });
    if (response.ok) latest = await response.json();
    else if (response.status !== 404) failed = true;
  } catch {
    failed = true;
  }

  const published = latest && latest.apkUrl && latest.versionName;
  if (published) {
    const meta = el("p", "meta");
    meta.append(el("span", "label", "Version"));
    meta.append(document.createTextNode(latest.versionName));
    meta.append(el("span", "code", `code ${latest.versionCode}`));
    card.append(meta);
    if (latest.publishedAt) {
      card.append(el("p", "when", `Published ${formatWhen(latest.publishedAt)}`));
    }
    if (latest.apkFileName) {
      card.append(el("p", "package", latest.apkFileName));
    }
    if (latest.notes) card.append(el("p", "notes", latest.notes));
    const link = el("a", "download", "Download APK");
    link.href = latest.apkUrl;
    link.rel = "noopener noreferrer";
    card.append(link);
    const sum = el("p", "sha");
    sum.append(el("span", "label", "SHA-256"));
    sum.append(el("code", null, latest.sha256 || ""));
    card.append(sum);
  } else if (failed) {
    card.append(el("p", "empty", "Could not check the latest release."));
  } else {
    card.append(el("p", "empty", "No public release yet."));
  }

  card.append(feedLink(app.id));
  return card;
}

async function load() {
  const response = await fetch("/apps.json", { cache: "no-cache" });
  if (!response.ok) throw new Error("Could not load the app list.");
  const catalog = await response.json();
  const cards = [];
  for (const app of catalog.apps) cards.push(await renderApp(app));
  list.replaceChildren(...cards);
}

load().catch((error) => {
  list.replaceChildren(el("p", "empty", error.message || "Could not load apps."));
});
