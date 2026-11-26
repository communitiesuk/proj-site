/* Coming next controls (ADR 0003, plan 0003 step 6).
 *
 * The page's template renders the rows grouped by theme, oldest first, and a
 * controls panel with `hidden`. This script shows the panel and "Open all",
 * and rearranges the existing rows and group headings when the reader groups
 * by theme or not, orders by date, or includes and excludes themes. It makes
 * no request to another site.
 *
 * arrange(items, options) -> groups
 *   items    [{theme, date, index}]: theme "" when the item has none; date
 *            "YYYY-MM-DD" or ""; index, the item's position in the rendered
 *            list, breaks ties between equal dates.
 *   options  {group: boolean, order: "oldest" | "newest", excluded: [theme]}
 *            ("" in excluded means items with no theme).
 *   Returns  [{theme, items}]. Items whose theme is excluded are dropped
 *            first. Grouped: one group per remaining theme in alphabetical
 *            order, then items with no theme (theme ""); ungrouped: one group
 *            with theme null. Within a group, items are ordered by date
 *            (oldest or newest first), undated items last in either order,
 *            then by index. No items left gives [].
 *   Pure: uses neither the page nor the items' other fields. Exported for
 *   Node when `module` exists.
 */
function arrange(items, options) {
  var excluded = options.excluded || [];
  var newest = options.order === "newest";
  var kept = items.filter(function (i) { return excluded.indexOf(i.theme || "") === -1; });
  function byDate(a, b) {
    var da = a.date || "", db = b.date || "";
    if (da !== db) {
      if (!da) return 1;
      if (!db) return -1;
      return (da < db) === newest ? 1 : -1;
    }
    return a.index - b.index;
  }
  if (!kept.length) return [];
  if (!options.group) return [{ theme: null, items: kept.slice().sort(byDate) }];
  var themes = [];
  kept.forEach(function (i) { if (i.theme && themes.indexOf(i.theme) === -1) themes.push(i.theme); });
  themes.sort(function (a, b) { return a < b ? -1 : a > b ? 1 : 0; });
  var groups = themes.map(function (t) {
    return { theme: t, items: kept.filter(function (i) { return i.theme === t; }).sort(byDate) };
  });
  var none = kept.filter(function (i) { return !i.theme; });
  if (none.length) groups.push({ theme: "", items: none.sort(byDate) });
  return groups;
}

if (typeof module !== "undefined") { module.exports = { arrange: arrange }; }

if (typeof document !== "undefined") (function () {
  var root = document.querySelector(".coming");
  if (!root) return;
  var openAll = root.querySelector(".open-all");
  if (openAll) {
    openAll.hidden = false;
    openAll.addEventListener("click", function () {
      root.querySelectorAll("details").forEach(function (d) { d.open = true; });
    });
  }
  var form = root.querySelector("form.controls"), list = root.querySelector(".groups");
  if (!form || !list) return;
  var items = Array.prototype.map.call(root.querySelectorAll("li.row"), function (li) {
    return { theme: li.getAttribute("data-item-theme") || "", date: li.getAttribute("data-date") || "",
             index: Number(li.getAttribute("data-index")), el: li };
  });
  function options() {
    var excluded = [];
    form.querySelectorAll('input[name="theme"]').forEach(function (b) { if (!b.checked) excluded.push(b.value); });
    return { group: form.elements.group.checked, order: form.elements.order.value, excluded: excluded };
  }
  function render() {
    var groups = arrange(items, options());
    while (list.firstChild) list.removeChild(list.firstChild);
    if (!groups.length) {
      var p = document.createElement("p"); p.className = "muted"; p.textContent = "No items match.";
      list.appendChild(p); return;
    }
    groups.forEach(function (g) {
      var section = document.createElement("section"); section.className = "group";
      if (g.theme !== null) {
        var h = document.createElement("h3"); h.textContent = g.theme || "No theme"; section.appendChild(h);
      }
      var ul = document.createElement("ul"); ul.className = "items";
      g.items.forEach(function (i) { ul.appendChild(i.el); });
      section.appendChild(ul); list.appendChild(section);
    });
  }
  form.addEventListener("change", render);
  form.addEventListener("submit", function (e) { e.preventDefault(); });
  form.querySelector(".reset").addEventListener("click", function () {
    form.elements.group.checked = true; form.elements.order.value = "oldest";
    form.querySelectorAll('input[name="theme"]').forEach(function (b) { b.checked = true; });
    render();
  });
  form.hidden = false;
})();
