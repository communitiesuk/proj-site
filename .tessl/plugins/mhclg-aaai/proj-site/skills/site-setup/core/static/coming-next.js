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
  throw new Error("arrange: not implemented");
}

if (typeof module !== "undefined") { module.exports = { arrange: arrange }; }
