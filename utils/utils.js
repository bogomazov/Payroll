var _ = require("lodash");
var Promise = require("bluebird");

module.exports = {
    assertEvent: function(contract, filter) {
        return new Promise((resolve, reject) => {
            console.log(contract)
            var event = contract.events[filter.event]();
            event.watch();
            event.get((error, logs) => {
                var log = _.filter(logs, filter);
                if (log) {
                    resolve(log);
                } else {
                    throw Error("Failed to find filtered event for " + filter.event);
                }
            });
            event.stopWatching();
        });
    }
}
