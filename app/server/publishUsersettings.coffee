Meteor.publish "usersettings", ->
	Meteor.users.find {_id: @userId}, fields: locationTopic: 1
