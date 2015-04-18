Restivus.configure
	useAuth: true
	prettyJson: true

Meteor.startup ->
	Restivus.addCollection Locations,
		routeOptions:
			authRequired: true