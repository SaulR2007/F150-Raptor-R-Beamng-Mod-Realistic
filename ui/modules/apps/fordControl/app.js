angular.module('beamng.apps')
.directive('fordControl', [function () {
  return {
    templateUrl: '/ui/modules/apps/fordControl/app.html',
    restrict: 'EA',
    replace: true,
    link: function (scope) {
      var DSE_LABELS = ['Slippery', 'Tow', 'Sport', 'Normal', 'Off-Road', 'Sand', 'Baja', 'Crawl'];
      var fourMap = { 0: '2H', 1: '4A', 2: '4H', 3: '4L' };

      scope.visible = true;
      scope.four = '2H';
      scope.dseName = 'Normal';
      scope.frontLock = false;
      scope.rearLock = false;
      scope.trailOn = false;
      scope.trailSpeed = 0;
      scope.speedUnit = 'km/h';

      function ge(cmd) {
        bngApi.engineLua('extensions.unload("user_fordControlGE"); extensions.load("user_fordControlGE"); ' + cmd);
      }

      function applyState(el) {
        if (!el) {
          return;
        }
        if (el.four !== undefined && fourMap[el.four] !== undefined) {
          scope.four = fourMap[el.four];
        }
        if (el.ford_4x4 !== undefined && fourMap[el.ford_4x4] !== undefined) {
          scope.four = fourMap[el.ford_4x4];
        }
        if (el.dse !== undefined && DSE_LABELS[el.dse]) {
          scope.dseName = DSE_LABELS[el.dse];
        }
        if (el.ford_dse !== undefined && DSE_LABELS[el.ford_dse]) {
          scope.dseName = DSE_LABELS[el.ford_dse];
        }
        if (el.fd !== undefined) {
          scope.frontLock = el.fd > 0.5;
        } else if (el.ford_fd !== undefined) {
          scope.frontLock = el.ford_fd > 0.5;
        }
        if (el.rd !== undefined) {
          scope.rearLock = el.rd > 0.5;
        } else if (el.ford_rd !== undefined) {
          scope.rearLock = el.ford_rd > 0.5;
        }
        if (el.tc !== undefined) {
          scope.trailOn = el.tc > 0.5;
        }
        if (el.spd !== undefined) {
          scope.trailSpeed = el.spd;
        } else if (el.mph !== undefined) {
          scope.trailSpeed = el.mph;
        }
        if (el.unit !== undefined) {
          scope.speedUnit = el.unit > 0 ? 'km/h' : 'mph';
        }
      }

      function refreshVisibility() {
        bngApi.engineLua('(function() extensions.load("user_fordControlGE") local m=extensions.user_fordControlGE if not m then return 0 end local fn=m.hasFordControlUI or m.isSddTrx2 if fn and fn() then return 1 end return 0 end)()', function (val) {
          scope.visible = val === 1 || val === '1' || val === true;
          if (scope.visible) {
            ge('extensions.user_fordControlGE.ensureVehicleExt()');
          }
          scope.$evalAsync();
        });
      }

      scope.setFour = function (mode) {
        ge('extensions.user_fordControlGE.setDriveMode("' + mode + '")');
      };

      scope.cycleDse = function (delta) {
        ge('extensions.user_fordControlGE.cycleDse(' + delta + ')');
      };

      scope.toggleDiff = function (which) {
        ge('extensions.user_fordControlGE.toggleDiff("' + which + '")');
      };

      scope.toggleTrail = function () {
        // Pass desired state so GE can unload+reload vehicle Lua then setTrail(on)
        ge('extensions.user_fordControlGE.toggleTrail(' + (!scope.trailOn) + ')');
      };

      scope.adjustTrail = function (delta) {
        ge('extensions.user_fordControlGE.adjustTrail(' + delta + ')');
      };

      scope.trailCam = function () {
        ge('extensions.user_fordControlGE.openTrailCamera()');
      };

      scope.$on('fordControlState', function (event, data) {
        applyState(data);
        scope.$evalAsync();
      });

      scope.$on('streamsUpdate', function (event, streams) {
        if (streams && streams.electrics) {
          applyState(streams.electrics);
        }
      });

      scope.$on('VehicleFocusChanged', refreshVisibility);
      scope.$on('VehicleChange', refreshVisibility);

      refreshVisibility();
    }
  };
}]);
