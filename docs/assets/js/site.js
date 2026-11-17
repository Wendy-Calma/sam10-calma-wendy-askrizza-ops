// Small progressive enhancements. The site works without them.
document.addEventListener("DOMContentLoaded", function () {
  var prose = document.querySelector(".prose");
  if (!prose) return;

  // Wide tables scroll sideways on small screens instead of overflowing the page.
  prose.querySelectorAll("table").forEach(function (table) {
    if (table.parentElement.classList.contains("table-wrap")) return;
    var wrap = document.createElement("div");
    wrap.className = "table-wrap";
    table.parentNode.insertBefore(wrap, table);
    wrap.appendChild(table);
  });

  // Screenshots become captioned figures (caption = alt text) that open full size.
  prose.querySelectorAll("p > img").forEach(function (img) {
    var p = img.parentElement;
    var imgs = p.querySelectorAll("img");
    var frag = document.createDocumentFragment();
    imgs.forEach(function (im) {
      var fig = document.createElement("figure");
      var link = document.createElement("a");
      link.href = im.getAttribute("src");
      link.target = "_blank";
      link.rel = "noopener";
      link.appendChild(im.cloneNode(true));
      fig.appendChild(link);
      if (im.alt) {
        var cap = document.createElement("figcaption");
        cap.textContent = im.alt;
        fig.appendChild(cap);
      }
      frag.appendChild(fig);
    });
    if (p.textContent.trim() === "") p.replaceWith(frag);
  });
});
