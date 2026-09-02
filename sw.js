/* Showcase Dojo Service Worker
 * Estratégia: cache-first para shell, network-first para fontes externas
 * Versão: bump CACHE_NAME para invalidar cache antigo após updates
 */

const CACHE_NAME = "dojo-v2.0.0";
const SHELL = [
  "./",
  "./index.html",
  "./db.js",
  "./manifest.json",
  "./icon-192.png",
  "./icon-512.png",
  "./apple-touch-icon.png",
  "./favicon-32.png"
];

// Install: pré-cacheia o app shell
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(SHELL))
      .then(() => self.skipWaiting())
  );
});

// Activate: remove caches antigos
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

// Fetch: cache-first com fallback de network e revalidação em background
self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;

  const url = new URL(req.url);

  // Supabase (REST/Auth): nunca intercepta. São respostas dinâmicas e
  // específicas do usuário (autenticadas) — cachear arriscaria servir
  // dado de outro usuário/sessão ou desperdiçar espaço à toa.
  if (url.hostname.endsWith("supabase.co")) {
    return;
  }

  // Google Fonts e o CDN do supabase-js: network-first, fallback cache
  if (
    url.hostname.includes("fonts.googleapis.com") ||
    url.hostname.includes("fonts.gstatic.com") ||
    url.hostname.includes("cdn.jsdelivr.net")
  ) {
    event.respondWith(
      fetch(req).then((res) => {
        const clone = res.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(req, clone));
        return res;
      }).catch(() => caches.match(req))
    );
    return;
  }

  // Mesmo origem: cache-first
  event.respondWith(
    caches.match(req).then((cached) => {
      if (cached) {
        // Background: revalida o cache (stale-while-revalidate)
        fetch(req).then((res) => {
          if (res && res.status === 200) {
            caches.open(CACHE_NAME).then((cache) => cache.put(req, res));
          }
        }).catch(() => {});
        return cached;
      }
      return fetch(req).then((res) => {
        if (!res || res.status !== 200 || res.type !== "basic") return res;
        const clone = res.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(req, clone));
        return res;
      }).catch(() => {
        // Fallback offline: index.html para navegação
        if (req.mode === "navigate") return caches.match("./index.html");
      });
    })
  );
});

// Notificações: handler quando o usuário clica
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((list) => {
      for (const client of list) {
        if ("focus" in client) return client.focus();
      }
      if (self.clients.openWindow) return self.clients.openWindow("./");
    })
  );
});
