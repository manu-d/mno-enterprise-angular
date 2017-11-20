angular.module('mnoEnterpriseAngular').component('connectAddonModal', {
  bindings: {
    resolve: '<'
    close: '&',
    dismiss: '&'
  },
  templateUrl: 'app/components/connect-addon-modal/connect-addon-modal.html',
  controller: (MnoeAppInstances, toastr, $translate) ->

    ctrl = this

    ctrl.app = null
    ctrl.model = {}
    ctrl.isFormLoading = true
    ctrl.isSubmitting = false
    ctrl.historicalData = false
    ctrl.date = new Date()

    ctrl.$onInit = ->
      ctrl.app = ctrl.resolve.app
      ctrl.currentStep = if ctrl.app.addon_organization.has_account_linked then 1 else 0
      MnoeAppInstances.getForm(ctrl.app).then((response) ->
        ctrl.schema = response.schema
        ctrl.form = [ "*" ]
        ctrl.isFormLoading = false
      )

    ctrl.submitForm = () ->
      ctrl.isSubmitting = true
      MnoeAppInstances.submitForm(ctrl.app, ctrl.model).then((response) ->
        if response.linking_error
          toastr.error(response.linking_error)
        else
          ctrl.app.addon_organization.has_account_linked = true
          ctrl.currentStep = 1
      ).finally(-> ctrl.isSubmitting = false)

    ctrl.unselectEntities = ->
      ctrl.currentStep = 1

    ctrl.forceSelectEntities = ->
      ctrl.currentStep = 2

    ctrl.update = ->
      ctrl.currentStep = 2

    ctrl.synchronize = (historicalData) ->
      MnoeAppInstances.sync(ctrl.app, historicalData)
      ctrl.app.addon_organization.sync_enabled = true
      ctrl.close()
      $translate('mno_enterprise.templates.components.addon_connect.sync.sync_launched').then((tls) ->
        toastr.success(tls)
      )

    return
})
