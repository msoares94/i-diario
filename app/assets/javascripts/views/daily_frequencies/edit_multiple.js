$(function () {
  var showConfirmation = $('#new_record').val() == 'true';

  // fix to checkboxes work correctly
  $('[name$="[present]"][type=hidden]').remove();

  var modalOptions = {
    title: 'Deseja salvar este lançamento antes de sair?',
    message: 'O Diário de frequência foi atualizado e agora é necessário apertar o botão "Salvar" ' +
             'ao fim do lançamento de frequência para que seja lançado com sucesso.',
    buttons: {
        confirm: { label: 'Salvar', className: 'btn new-save-style' },
        cancel: { label: 'Continuar sem salvar', className: 'btn new-delete-style' }
    }
  };

  $('a').on('click', function(e) {
    if (!showConfirmation) {
      return true;
    }

    e.preventDefault();
    showConfirmation = false;

    modalOptions = Object.assign(modalOptions, {
      callback: function(result) {
        if (result) {
          $('input[type=submit]').click();
        } else {
          e.target.click();
        }
      }
    });

    bootbox.confirm(modalOptions);
  });

  $(document).mouseleave(function () {
    if (!showConfirmation) {
      return false;
    }

    showConfirmation = false;

    modalOptions = Object.assign(modalOptions, {
      callback: function(result) {
        if (result) {
          $('input[type=submit]').click();
        }
      }
    });

    bootbox.confirm(modalOptions);
  });

  setTimeout(function() {
    $('.alert-success').hide();
  }, 5000);

  $('[name$="[present]"]').on('change', function (e) {
    showConfirmation = true;
  });
});
