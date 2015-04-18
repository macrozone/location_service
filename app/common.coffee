
@Locations = new Meteor.Collection "Locations"

@AdminConfig = 
	collections: 
		Locations: {}

Meteor.users.attachSchema new SimpleSchema
	services:
		type: Object
		optional: yes
		blackbox: yes
		autoform:
			omit: yes
	locationTopic:
		type: String
		label: "Location topic"
		optional: yes