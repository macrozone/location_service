Router.route "/settings",
	template: "usersettings"
	layoutTemplate: "layout"
	waitOn: -> Meteor.subscribe "usersettings"
	data: -> user: -> Meteor.user()