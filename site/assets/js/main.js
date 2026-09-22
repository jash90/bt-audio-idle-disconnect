// Screenshot lightbox: every .shot-button opens its image in a native <dialog>.
// Without JS the buttons are inert and the page still reads fine.
(function () {
  var dialog = document.getElementById('lightbox');
  if (!dialog || typeof dialog.showModal !== 'function') return;

  var img = dialog.querySelector('img');
  var caption = dialog.querySelector('p');
  var closeBtn = dialog.querySelector('.lightbox-close');
  var opener = null;

  document.querySelectorAll('.shot-button').forEach(function (button) {
    button.addEventListener('click', function () {
      var source = button.querySelector('img');
      opener = button;
      // currentSrc follows the <picture> source picked for the colour scheme.
      img.src = source.currentSrc || source.src;
      img.alt = source.alt;
      caption.textContent = button.getAttribute('data-caption') || source.alt;
      dialog.showModal();
      closeBtn.focus();
    });
  });

  closeBtn.addEventListener('click', function () { dialog.close(); });
  dialog.addEventListener('click', function (event) {
    if (event.target === dialog) dialog.close();
  });
  dialog.addEventListener('close', function () {
    img.removeAttribute('src');
    if (opener) opener.focus();
  });
})();
