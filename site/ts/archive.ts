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
    let shown = 0;
    for (const e of entries) {
      const ok =
        (!needle || (e.dataset.search ?? "").includes(needle)) &&
        (!ent || (e.dataset.entities ?? "").split(", ").includes(ent)) &&
        (!era || e.dataset.era === era) &&
        (!kind || (e.dataset.kind ?? "").replace(/_/g, " ") === kind);
      e.hidden = !ok;
      if (ok) shown++;
    }
    count.textContent = String(shown);
    empty.hidden = shown !== 0;
    clear.hidden = !(needle || ent || era || kind);
  };

  for (const el of [q, fEntity, fEra, fKind]) {
    el.addEventListener("input", apply);
    el.addEventListener("change", apply);
  }
  clear.addEventListener("click", () => {
    q.value = "";
    fEntity.value = "";
    fEra.value = "";
    fKind.value = "";
    apply();
    q.focus();
  });

  // Deep links: open the <details> that matches the URL fragment.
  if (location.hash) {
    const target = document.querySelector<HTMLDetailsElement>(
      `.entry${CSS.escape(location.hash)}`.replace("entry#", "entry#")
    );
    if (target?.tagName === "DETAILS") {
      (target as HTMLDetailsElement).open = true;
      target.scrollIntoView({ block: "start" });
    }
  }
}
