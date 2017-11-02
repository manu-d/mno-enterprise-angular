
angular.module 'mnoEnterpriseAngular'
  .controller('DashboardAppSettingsModalCtrl', ($scope, MnoConfirm, MnoeOrganizations, $uibModalInstance, MnoeAppInstances, Utilities, app, $window, ImpacMainSvc, toastr, $translate)->

    $scope.modal ||= {}
    $scope.app = app
    $scope.sentence = "Please proceed to the deletion of my app and all data it contains"
    $scope.organization_uid = ImpacMainSvc.config.currentOrganization.uid
    $scope.isDisconnecting = false
    $scope.syncs = {
      list: []
      sort: '-updated_at'
      baseSize: 5
      page: 1
      loading: false
      pageChangedCb: (nbItems, page) ->
        $scope.syncs.baseSize = nbItems
        $scope.syncs.page = page
        $scope.loadSyncs()
    }
    $scope.idMaps = {
      entityName: "All"
      list: []
      sort: 'name'
      baseSize: 5
      page: 1
      loading: false
      pageChangedCb: (nbItems, page) ->
        $scope.idMaps.baseSize = nbItems
        $scope.idMaps.page = page
        $scope.loadIdMaps($scope.idMaps.externalNames)
    }
    $scope.mnoSyncsTableFields = [{ header: 'Date', attr: 'updated_at'}, { header: 'Status', attr: 'status'}, { header: 'Message', attr: 'message'}]
    $scope.mnoIdMapsTableFields = [{ header: 'Name', attr: 'name'}, { header: 'Type', attr: 'external_entity'}, { header: 'In Maestrano', attr: 'connec_id'}, { header: 'In Neto', attr: 'external_id'}]

    this.$onInit = ->
      if MnoeAppInstances.isAddOnWithOrg(app)
        $scope.loadSyncs()

    # ----------------------------------------------------------
    # Initialize deletion sentence
    # ----------------------------------------------------------
    $translate('mno_enterprise.templates.impac.dock.settings.deletion_sentence').then(
      (result) ->
        $scope.sentence = result
    )

    # ----------------------------------------------------------
    # Permissions helper
    # ----------------------------------------------------------

    $scope.helper = {}
    $scope.helper.canDeleteApp = ->
      MnoeOrganizations.can.destroy.appInstance()

    $scope.modal.close = ->
      $uibModalInstance.close()

    #====================================
    # App deletion modal
    #====================================
    $scope.deleteApp = ->
      $scope.modal.loading = true
      MnoeAppInstances.terminate($scope.app.id).then(
        ->
          $scope.modal.errors = null
          $uibModalInstance.close()
        (error) ->
          $scope.modal.errors = Utilities.processRailsError(error)
      ).finally(-> $scope.modal.loading = false)

    $scope.helper.isDataSyncShown = (app) ->
      app.stack == 'connector' && app.oauth_keys_valid

    $scope.helper.isDataDisconnectShown = (app) ->
      app.stack == 'connector' && app.oauth_keys_valid

    $scope.helper.dataSyncPath = (app) ->
      "/mnoe/webhook/oauth/#{app.uid}/sync"

    $scope.helper.companyName = (app) ->
      if app.stack == 'connector' && app.oauth_keys_valid && app.oauth_company_name
        return app.oauth_company_name
      false

    $scope.helper.isAddOnSettingShown = (app) ->
      MnoeAppInstances.isAddOnWithOrg(app) &&
      app.addon_organization.has_account_linked

    $scope.helper.addOnSettingLauch = (app) ->
      $window.open("/mnoe/launch/#{app.uid}?settings=true", '_blank')
      return true

    $scope.helper.dataDisconnectClick = (app) ->
      modalOptions =
        closeButtonText: 'Cancel'
        actionButtonText: 'Disconnect app'
        headerText: "Disconnect #{app.app_name}?"
        bodyText: "Are you sure you want to disconnect #{app.app_name} and Maestrano?"

      MnoConfirm.showModal(modalOptions).then(
        ->
          MnoeAppInstances.clearCache()
          $window.location.href = "/mnoe/webhook/oauth/#{app.uid}/disconnect"
      )

    $scope.loadSyncs = ->
      $scope.syncs.loading = true
      params = {
        per_page: $scope.syncs.baseSize,
        page: $scope.syncs.page,
        sort: $scope.syncs.sort
      }
      MnoeAppInstances.getSyncs($scope.app, params)
        .then((response) ->
          $scope.syncs.list = _.map(response.data, 'attributes')
          $scope.syncs.totalItems = response.headers('x-total-count')
          $scope.syncs.loading = false
        )

    searchInput = ->
      htmlTemplate = '<input placeholder="search name" ng-model="input" ng-change="changeInput(input)"/>'
      {
        scope:
          input: ''
          changeInput: (input) ->
            if input.length > 2
              $scope.loadIdMaps($scope.idMaps.entityName, input)
        template: htmlTemplate
      }

    optionsForEntities = (data) ->
      htmlTemplate = '<select ng-init="model=types[getIndexFromValue(model, types)]" ng-model="model" ng-change="changeEntity(model)" ng-options="option for option in types"></select>'
      {
        scope:
          model: data[0]
          types: data[1]
          changeEntity: (model) ->
            $scope.loadIdMaps(model)
          getIndexFromValue: (value, array) ->
            i = 0
            for type in array
              if type == value
                return i
              i++
            return 0

        template: htmlTemplate
      }

    $scope.loadIdMaps = (externalName, input = null) ->
      $scope.idMaps.loading = true
      $scope.idMaps.entityName = externalName
      params = {
        per_page: $scope.idMaps.baseSize,
        page: $scope.idMaps.page,
        sort: $scope.idMaps.sort
      }
      params['filter[name.like]'] = ('%' + input + '%') if input
      params['filter[external_entity.in]'] = externalName unless externalName == "All"
      MnoeAppInstances.getIdMaps($scope.app, params)
        .then((response) ->
          $scope.mnoIdMapsSubHeaders = [
            {render: searchInput},
            {render: optionsForEntities, data: [$scope.idMaps.entityName, $scope.app.addon_organization.entities_types]},
            {},
            {}
          ] unless input
          $scope.idMaps.list = response.data.map (e) ->
            att = e.attributes
            att.connec_id = if att.connec_id then '&#9989;' else '&#10060;'
            att.external_id = if att.external_id then '&#9989;' else '&#10060;'
            att
          $scope.idMaps.totalItems = response.headers('x-total-count')
          $scope.idMaps.loading = false
        )

    $scope.disconnect = ->
      $scope.isDisconnecting = true
      MnoeAppInstances.disconnect(app)
        .then((response) ->
          app.addon_organization.has_account_linked = false
          app.addon_organization.sync_enabled = false
          $uibModalInstance.close()
          toastr.success("Your application has been disconnected")
          $scope.isDisconnecting = false
        )

    $scope.sortableSyncsServerPipe = (tableState)->
      $scope.syncs.sort = updateTableSort(tableState.sort, $scope.syncs.sort)
      $scope.loadSyncs()

    $scope.sortableIdMapsServerPipe = (tableState)->
      $scope.idMaps.sort = updateTableSort(tableState.sort, $scope.idMaps.sort)
      $scope.loadIdMaps($scope.idMaps.entityName)

    updateTableSort = (sortState = {}, sort) ->
      if sortState.predicate
        sort = sortState.predicate
        sort = "-#{sort}" if sortState.reverse
      return sort

    $scope.selectHistory = ->
      $scope.isLeftFooterButtonShown = true
      $scope.selectedTab = 0
      $scope.textForFooterButton = "Synchronize"

    $scope.selectEntities = ->
      $scope.isLeftFooterButtonShown = true
      $scope.selectedTab = 2
      $scope.textForFooterButton = "Update"

    $scope.selectData = ->
      $scope.isLeftFooterButtonShown = false

    $scope.callToAction = ->
      switch $scope.selectedTab
        when 0
          MnoeAppInstances.sync($scope.app)
          toastr.success("The sync with Neto has started")

    return

  )
