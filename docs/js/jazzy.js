// Jazzy - https://github.com/realm/jazzy
// Copyright Realm Inc.
// SPDX-License-Identifier: MIT

window.jazzy = {'docset': false}
if (typeof window.dash != 'undefined') {
  document.documentElement.className += ' dash'
  window.jazzy.docset = true
}
if (navigator.userAgent.match(/xcode/i)) {
  document.documentElement.className += ' xcode'
  window.jazzy.docset = true
}

function toggleItem($link, $content) {
  var animationDuration = 300;
  $link.toggleClass('token-open');
  $content.slideToggle(animationDuration);
}

function itemLinkToContent($link) {
  return $link.parent().parent().next();
}

// On doc load + hash-change, open any targeted item
function openCurrentItemIfClosed() {
  if (window.jazzy.docset) {
    return;
  }
  var $link = $(`a[name="${location.hash.substring(1)}"]`).nextAll('.token');
  $content = itemLinkToContent($link);
  if ($content.is(':hidden')) {
    toggleItem($link, $content);
  }
}

$(openCurrentItemIfClosed);
$(window).on('hashchange', openCurrentItemIfClosed);

// On item link ('token') click, toggle its discussion
$('.token').on('click', function(event) {
  if (window.jazzy.docset) {
    return;
  }
  var $link = $(this);
  toggleItem($link, itemLinkToContent($link));

  // Keeps the document from jumping to the hash.
  var href = $link.attr('href');
  if (history.pushState) {
    history.pushState({}, '', href);
  } else {
    location.hash = href;
  }
  event.preventDefault();
});

// Clicks on links to the current, closed, item need to open the item
$("a:not('.token')").on('click', function() {
  if (location == this.href) {
    openCurrentItemIfClosed();
  }
});

// KaTeX rendering
if ("katex" in window) {
  $($('.math').each( (_, element) => {
    katex.render(element.textContent, element, {
      displayMode: $(element).hasClass('m-block'),
      throwOnError: false,
      trust: true
    });
  }))
}
