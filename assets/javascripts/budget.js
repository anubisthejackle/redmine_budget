$(function() {
  var URL_ROOT = (function() {
    var s = window.location.pathname.split('/'),
        i = s.indexOf('deliverables');

    if (s.indexOf('projects') >= 0) i -= 2;

    return (i > 0 ? s.slice(0, i).join('/') : '/');
  })();

  var selector = '.deliverable-calculator input';

  $(selector).on('change', function calculate() {
    var $calc = $(this).closest('.deliverable-calculator');

    $.ajax({
      type: 'POST',
      url: URL_ROOT + '/deliverables/calculator',
      data: $calc.find('input').serialize(),
      cache: false,
      success: function(data) {
        var lastFocusedName = $calc.find('input:focus').attr('name');

        $calc.html(data);
        $calc.find('input[name="' + lastFocusedName + '"]').focus().select();

        $(selector).on('change', calculate);
      }
    });
  });

  $('#new_deliverable, .edit_deliverable').on('change', '#deliverable_status_id', function() {
    $.ajax({
      url: URL_ROOT + '/deliverables/update_form.js',
      type: 'POST',
      dataType: 'script',
      data: $(this).closest('form').find('[name^="deliverable"]').serialize()
    });
  });

});

$(function() {
  var $assigns = $('.deliverable-assigns');

  $('#deliverable_budget_attributes_total_hours').on('change', function() {
    var i = parseFloat(this.value),
        assignsTotal = 0;

    if (isNaN(i)) {
      $(this).val('');
      return;
    }

    // If inputted value is lower than sum of assign's hour, lower it
    $assigns.find('input.hours').each(function() {
      var i = parseFloat(this.value);
      if (!isNaN(i)) assignsTotal += i;
    });

    $assigns.find('.deliverable-assigns-sum').text(assignsTotal);

    if (i < assignsTotal) $(this).val(assignsTotal);
  });

  $assigns
    .on('click', '.icon-del', function() {
      $(this).closest('tr')
            .hide()
            .find('.deliverable-assign-destroy').val(1);
    })
    .on('click', '.icon-add', function() {
      var $tr = $assigns.find('.deliverable-assign-empty').first(),
          $clone = $tr.clone(),
          invalid = null;


      $clone.removeClass('deliverable-assign-empty');

      $clone.find('.user').on('select[data-name]', function() {
        var name = $(this).data('name');
        $(this).closest('tr').attr('data-' + name, $(this).val());
      });

      $assigns.find('.deliverable-assign-empty').before($clone);
    })
    .on('change', '.user', function() {
      var $tr = $(this).closest('tr'),
          user = $(this).val(),
          usedRoles = [];

      // after changing user, reset enumeration field
      $tr.find('select[data-name="activity"]').val('')
        .find('option[disabled]').removeAttr('disabled');

      // find all used roles by given user
      $assigns.find('.deliverable-assign[data-user="' + user + '"]:visible select[data-name="activity"]').each(function() {
        usedRoles.push($(this).val());
      });

      $tr.find('[disabled]').removeAttr('disabled');

      // disable used roles
      $tr.find('select[data-name="activity"] > option').each(function() {
        if (usedRoles.indexOf($(this).val()) != -1) {
          $(this).attr('disabled', true);
        }
      });
    })
    .on('change', '.hours', function() {
      if (isNaN(parseInt(this.value))) {
        $(this).val(0);
      }

      var sum = 0,
          max = parseInt($('#deliverable_budget_attributes_total_hours').val());

      // calculate sum
      $assigns.find('.deliverable-assign:visible .hours').each(function() {
        var i = parseInt(this.value);
        if (i) sum += i;
      });

      if (sum > max) {
        var overflow = sum - max;

        $(this).val(this.value - overflow);
        $(this).effect('shake', { distance: 5, times: 2 });

        sum -= overflow;
      }

      $assigns.find('.deliverable-assigns-sum').val(sum);
    });
});


$(function() {
  $('.list.deliverables tr.deliverable a').on('click', function(e) {
    e.stopPropagation();
  });

  $('.list.deliverables').on('click', '.deliverable-expander', function(e) {
    var $tr = $(this).parent().parent();

    $tr.nextUntil('.deliverable, .group').toggle();
    $tr.toggleClass('open');

    e.stopPropagation();
  });

  $('.list.deliverables').on('change', '.deliverable-version-assign', function() {
    if ($(this).val().length == 0)  return;

    $.post($(this).data('url'), { version_id: $(this).val() }, function()  {
      location.reload();
    });

    return false;
  });
});
