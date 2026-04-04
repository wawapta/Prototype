// WaWa Service Worker — オフライン対応 + 参加記録キュー
const CACHE_NAME = 'wawa-v1';
const STATIC_ASSETS = [
  './',
  './index.html',
  './config.js',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.39.3/dist/umd/supabase.min.js',
  'https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js'
];

// インストール：静的アセットをキャッシュ
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => {
      return cache.addAll(STATIC_ASSETS).catch(() => {
        // 外部CDNのキャッシュに失敗しても続行
        return cache.addAll(['./index.html', './config.js']);
      });
    }).then(() => self.skipWaiting())
  );
});

// アクティベート：古いキャッシュを削除
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

// フェッチ：Supabase APIはネットワーク優先、それ以外はキャッシュフォールバック
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);

  // Supabase APIリクエストはネットワーク優先
  if (url.hostname.includes('supabase.co')) {
    event.respondWith(
      fetch(event.request).catch(() => {
        // オフライン時：GETは503、POSTはキューに追加
        if (event.request.method === 'POST') {
          return queueOfflineRequest(event.request.clone()).then(() =>
            new Response(JSON.stringify({error:'offline',queued:true}), {
              status: 202,
              headers: {'Content-Type':'application/json'}
            })
          );
        }
        return new Response(JSON.stringify([]), {
          status: 503,
          headers: {'Content-Type':'application/json'}
        });
      })
    );
    return;
  }

  // 静的アセット：キャッシュ優先
  event.respondWith(
    caches.match(event.request).then(cached => {
      if (cached) return cached;
      return fetch(event.request).then(response => {
        if (response && response.status === 200 && event.request.method === 'GET') {
          const clone = response.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
        }
        return response;
      }).catch(() => {
        // HTMLリクエストにはindex.htmlを返す
        if (event.request.headers.get('accept')?.includes('text/html')) {
          return caches.match('./index.html');
        }
      });
    })
  );
});

// オフラインキュー（IndexedDB）
const DB_NAME = 'wawa-offline';
const STORE = 'pending';

function openDB() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = e => {
      e.target.result.createObjectStore(STORE, {keyPath: 'id', autoIncrement: true});
    };
    req.onsuccess = e => resolve(e.target.result);
    req.onerror = e => reject(e.target.error);
  });
}

async function queueOfflineRequest(request) {
  try {
    const body = await request.text();
    const db = await openDB();
    const tx = db.transaction(STORE, 'readwrite');
    tx.objectStore(STORE).add({
      url: request.url,
      method: request.method,
      headers: Object.fromEntries(request.headers.entries()),
      body,
      timestamp: Date.now()
    });
    return new Promise((resolve, reject) => {
      tx.oncomplete = resolve;
      tx.onerror = reject;
    });
  } catch(e) {
    console.warn('SW: キューへの追加失敗', e);
  }
}

async function flushQueue() {
  let db;
  try {
    db = await openDB();
  } catch(e) { return; }

  const tx = db.transaction(STORE, 'readwrite');
  const store = tx.objectStore(STORE);
  const all = await new Promise((resolve, reject) => {
    const req = store.getAll();
    req.onsuccess = e => resolve(e.target.result);
    req.onerror = reject;
  });

  for (const item of all) {
    try {
      const resp = await fetch(item.url, {
        method: item.method,
        headers: item.headers,
        body: item.body
      });
      if (resp.ok) {
        const tx2 = db.transaction(STORE, 'readwrite');
        tx2.objectStore(STORE).delete(item.id);
        // クライアントに同期完了を通知
        const clients = await self.clients.matchAll();
        clients.forEach(c => c.postMessage({type: 'SYNC_COMPLETE', item}));
      }
    } catch(e) {
      // まだオフライン — スキップ
      break;
    }
  }
}

// オンライン復帰時にキューを処理
self.addEventListener('sync', event => {
  if (event.tag === 'wawa-sync') {
    event.waitUntil(flushQueue());
  }
});

// メッセージ受信（手動同期トリガー）
self.addEventListener('message', event => {
  if (event.data?.type === 'FLUSH_QUEUE') {
    flushQueue();
  }
});
