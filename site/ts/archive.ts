/**
 * archive.ts — lore page: search, entity/era/source filters, deep links.
 */

export function initFilters(): void {
  const form = document.getElementById("filters");
  if (!form) return;
  const q = document.getElementById("f-q") as HTMLInputElement | null;
  const fEntity = document.getElementById("f-entity") as HTMLSelectElement | null;
  const fEra = document.getElementById("f-era") as HTMLSelectElement | null;
  const fKind = document.getElementById("f-kind") as HTMLSelectElement | null;
  const count = document.getElementById("f-count");
  const clear = document.getElementById("f-clear") as HTMLButtonElement | null;
  const empty = document.getElementById("f-empty");
  const entries = Array.from(document.querySelectorAll<HTMLElement>(".entry"));
  if (!q || !fEntity || !fEra || !fKind || !count || !clear || !empty) return;

  const apply = (): void => {
    const needle = q.value.trim().toLowerCase();
    const ent = fEntity.value;
    const era = fEra.value;
    const kind = fKind.value;
    const isFiltering = Boolean(needle || ent || era || kind);
    let shown = 0;
    for (const e of entries) {
      const ok =
        (!needle || (e.dataset.search ?? "").includes(needle) || (e.textContent ?? "").toLowerCase().includes(needle)) &&
        (!ent || (e.dataset.entities ?? "").split(", ").includes(ent)) &&
        (!era || e.dataset.era === era) &&
        (!kind || (e.dataset.kind ?? "").replace(/_/g, " ") === kind);
      e.hidden = !ok;
      if (ok) {
        shown++;
        if (isFiltering && e.tagName === "DETAILS") {
          (e as HTMLDetailsElement).open = true;
        }
      } else if (e.tagName === "DETAILS") {
        (e as HTMLDetailsElement).open = false;
      }
    }
    count.textContent = String(shown);
    empty.hidden = shown !== 0;
    clear.hidden = !isFiltering;
  };

  form.addEventListener("submit", (e) => e.preventDefault());
  for (const el of [q, fEntity, fEra, fKind]) {
    el.addEventListener("input", apply);
    el.addEventListener("change", apply);
  }
  clear.addEventListener("click", () => {
    q.value = "";
    fEntity.value = "";
    fEra.value = "";
    fKind.value = "";
    for (const e of entries) {
      if (e.tagName === "DETAILS") {
        (e as HTMLDetailsElement).open = false;
      }
    }
    apply();
    q.focus();
  });

  // Deep links: open the <details> that matches the URL fragment.
  const openHash = (): void => {
    if (location.hash.length > 1) {
      const target = document.getElementById(location.hash.slice(1));
      if (target?.tagName === "DETAILS") {
        (target as HTMLDetailsElement).open = true;
        target.scrollIntoView({ block: "start" });
      }
    }
  };
  openHash();
  window.addEventListener("hashchange", openHash);
}
