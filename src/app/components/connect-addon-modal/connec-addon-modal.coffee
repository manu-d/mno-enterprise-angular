angular.module('mnoEnterpriseAngular').component('connectAddonModal', {
  bindings: {
    resolve: '<'
    close: '&',
    dismiss: '&'
  },
  templateUrl: 'app/components/connect-addon-modal/connect-addon-modal.html',
  controller: (MnoeAppInstances, toastr) ->

    ctrl = this

    ctrl.app = null
    ctrl.model = {}
    ctrl.hasLinked = false
    ctrl.hasChosenEntities = false
    ctrl.historicalData = false
    ctrl.isFormLoading = true
    ctrl.isSubmitting = false
    ctrl.historicalData = false
    ctrl.date = new Date()

    ctrl.$onInit = ->
      ctrl.app = ctrl.resolve.app
      ctrl.hasLinked = ctrl.app.addon_organization.has_account_linked
      MnoeAppInstances.getForm(ctrl.app)
        .then((response) ->
          ctrl.schema = response.schema
          ctrl.form = [ "*" ]
          ctrl.isFormLoading = false
        )

    ctrl.close = ->
      ctrl.close()

    ctrl.submit = (form) ->
      ctrl.isSubmitting = true
      MnoeAppInstances.submitForm(ctrl.app, ctrl.model)
        .then((response) ->
          if response.error
            toastr.error(response.error)
          else
            ctrl.app.addon_organization.has_account_linked = true
            ctrl.hasLinked = true
          ctrl.isSubmitting = false
        )

    ctrl.unselectEntities = ->
      ctrl.hasChosenEntities = false

    ctrl.forceSelectEntities = ->
      ctrl.hasChosenEntities = true

    ctrl.update = (entities) ->
      ctrl.hasChosenEntities = true

    ctrl.synchronize = (historicalData) ->
      MnoeAppInstances.sync(ctrl.app, ctrl.historicalData)
      ctrl.app.addon_organization.sync_enabled = true
      ctrl.close()
      toastr.success("Congratulations, your data is now being synced!")

    ctrl.titleForButton = ->
      if !ctrl.hasLinked
        "Submit"
      else if !ctrl.hasChosenEntities
        "Update"
      else
        "Start synchronizing"

    ctrl.callToAction = (connectForm, historicalData)->
      if !ctrl.hasLinked
        ctrl.submit(connectForm)
      else if !ctrl.hasChosenEntities
        ctrl.update(ctrl.app.addon_organization.synchronized_entities)
      else
        ctrl.synchronize(ctrl.historicalData)

    return
})
