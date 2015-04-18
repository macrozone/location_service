
## collections

we need a Collection to store the locations of the users.

	@Locations = new Meteor.Collection "Locations"

define shared helper functions to get the topic string for a user or vis-verca

	@Topic = 
		getTopicForUser: (user) -> "location/#{user._id}"
		getUserIdForTopic: (topic) -> topic.split("/")[1]
		getUserForTopic: (topic) -> Meteor.users.findOne @getUserIdForTopic topic


define Tabulars for aldeed:tabular

	@TabularTables = {}
	Template.registerHelper('TabularTables', @TabularTables) if Meteor.isClient
	@TabularTables.Locations = new Tabular.Table
		name: "Locations"
		collection: Locations
		order: [[0, "desc"]]
		selector: (userId) -> {userId}
		columns: [
			##{	data: "_id", title: "ID"}
			{
				data: "tst"
				title: "Time"
				render: (val) ->
					moment(val).calendar()
			},
			{
				data: "geo"
				title: "Address"
				render: (geo) ->
					"#{geo.city}, #{geo.streetName} #{geo.streetNumber}" if geo?
			}
			
			{data: "lat", title: "Latitude", width: "80px"}
			{data: "lon", title: "Longitude", width: "80px"}
			{data: "batt", title: "Battery", width: "40px"}
			]
