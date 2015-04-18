Meteor.publish "myLocations", (params)->
	selector = userId: @userId
	if params.from?
		selector.tst ?= {}
		selector.tst["$gte"] = params.from
	if params.to?
		selector.tst ?= {}
		selector.tst["$lte"] = params.to
	Locations.find selector