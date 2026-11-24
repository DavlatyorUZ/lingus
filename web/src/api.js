export class ApiError extends Error {
  constructor(message, status = 0) {
    super(message);
    this.status = status;
  }
}
let access = "",
  csrf = "",
  refreshing;
function cachedUser(value) {
  try {
    const u = JSON.parse(value || "null");
    return u &&
      typeof u.id === "string" &&
      typeof u.name === "string" &&
      u.name.trim() &&
      typeof u.email === "string"
      ? u
      : null;
  } catch {
    return null;
  }
}
export let user;
try {
  user = cachedUser(localStorage.getItem("lingoy-user"));
} catch {
  user = null;
}
const profileKey = (u) =>
  JSON.stringify(u && [u.id, u.name, u.email, u.picture, u.hasPassword]);
export function accept(data) {
  const before = profileKey(user);
  access = data?.accessToken || "";
  user = data?.user || null;
  try {
    localStorage.setItem("lingoy-user", JSON.stringify(user));
  } catch {
    /* The current session still works when storage is unavailable. */
  }
  if (before !== profileKey(user))
    window.dispatchEvent(new Event("accountchange"));
}
window.addEventListener("storage", (event) => {
  if (event.key !== "lingoy-user" && event.key !== null) return;
  const before = profileKey(user);
  user = cachedUser(event.key === null ? null : event.newValue);
  access = "";
  csrf = "";
  if (before !== profileKey(user))
    window.dispatchEvent(new Event("accountchange"));
});
async function raw(path, { method = "GET", body } = {}) {
  let r;
  try {
    r = await fetch("/api/v1" + path, {
      method,
      credentials: "same-origin",
      signal: AbortSignal.timeout(70000),
      cache: "no-store",
      headers: {
        "Content-Type": "application/json",
        ...(access ? { Authorization: "Bearer " + access } : {}),
        ...(csrf ? { "X-CSRF-Token": csrf } : {}),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
  } catch {
    throw new ApiError("Internetga ulanishni tekshiring.");
  }
  let p;
  try {
    p = await r.json();
  } catch {
    throw new ApiError("Server javobi kelmadi.", r.status);
  }
  if (!r.ok) throw new ApiError(p.message || "So‘rov bajarilmadi.", r.status);
  return p;
}
async function getCsrf() {
  csrf = (await raw("/auth/csrf")).csrfToken;
}
export function refresh() {
  return (refreshing ||= (async () => {
    const rotate = async () => {
      await getCsrf();
      accept(await raw("/auth/refresh", { method: "POST", body: {} }));
    };
    if (navigator.locks)
      await navigator.locks.request("lingoy-refresh", rotate);
    else await rotate();
  })().finally(() => (refreshing = null)));
}
export async function api(path, { method = "GET", body } = {}) {
  const identity = user?.id;
  const sameAccount = () => {
    if (identity && !path.startsWith("/auth/") && user?.id !== identity) {
      throw new ApiError("Akkaunt o‘zgardi. So‘rovni qayta boshlang.", 401);
    }
  };
  if (method !== "GET" && !csrf) await getCsrf();
  sameAccount();
  try {
    return await raw(path, { method, body });
  } catch (e) {
    sameAccount();
    if (e.status === 401 && user && !path.startsWith("/auth/")) {
      try {
        await refresh();
      } catch (r) {
        if (r.status === 401 && user?.id === identity) accept(null);
        throw r;
      }
      sameAccount();
      return raw(path, { method, body });
    }
    if (e.status === 403 && method !== "GET") {
      await getCsrf();
      sameAccount();
      return raw(path, { method, body });
    }
    throw e;
  }
}
export async function restore() {
  try {
    await refresh();
  } catch (e) {
    if (e.status === 401) accept(null);
  }
}
export async function logout() {
  await api("/auth/logout", { method: "POST", body: {} });
  accept(null);
}
