var mn = mn || {};
mn.components = mn.components || {};
mn.components.MnUserRolesItem =
  (function () {
    "use strict";

    mn.helper.extends(MnUserRolesItemComponent, mn.helper.MnEventableComponent);

    MnUserRolesItemComponent.annotations = [
      new ng.core.Component({
        selector: "mn-user-roles-item",
        templateUrl: "app-new/mn-user-roles-item.html",
        inputs: [
          "user"
        ]
      })
    ];

    MnUserRolesItemComponent.parameters = [
      mn.services.MnPermissions,
      mn.services.MnUserRoles,
      window['@uirouter/angular'].UIRouter
    ];

    return MnUserRolesItemComponent;

    function MnUserRolesItemComponent(mnPermissionsService, mnUserRolesService, uiRouter) {
      mn.helper.MnEventableComponent.call(this);

      var userCurrentValue = this.mnOnChanges.pluck("user", "currentValue");

      var userId = userCurrentValue.map(function (user) {
        return user.id + user.domain;
      });

      this.securityWrite =
        mnPermissionsService.createPermissionStream("admin.security!write");

      this.userRoles =
        mnUserRolesService.stream
        .getRolesByRole
        .combineLatest(userCurrentValue)
        .map(function (resp) {
          var rolesByRole = resp[0];
          var user = resp[1];
          user.roles.forEach(function (role, index) {
            var roleId = role.role + (role.bucket_name || '');
            user.roles[index].desc = rolesByRole[roleId].desc;
            user.roles[index].name = rolesByRole[roleId].name;
          });
          return user.roles;
        });

      this.detailsHashObserver =
        new mn.helper.DetailsHashObserver(
          uiRouter,
          "app.admin.security.userRoles",
          "openedUsers",
          this.mnOnDestroy,
          userId
        );
    }

  })();
