
# Simple location service with Meteor - app.coffee.md

This app connects to a mqtt-broker that will receive location-data from "OwnTracks" 
and will expose it in

- a table (using aldeed:tabular)
- a google map
- a DDP-API
- a REST-API (using nimble:restivus)

## Collections

First we need a collection to store the locations of the users.

	@Collections = 
		Locations: new Meteor.Collection "Locations"

We define now a shared helper functions to get the topic string for a user or vis-verca. 
The topics have the pattern location/:userId

	Topic = 
		getTopicForUser: (user) -> "location/#{user._id}"
		getUserIdForTopic: (topic) -> topic.split("/")[1]
		getUserForTopic: (topic) -> Meteor.users.findOne @getUserIdForTopic topic

## DDP-API

We publish the data, so that a ddp client can subscribe to the data with subscribe "myLocations", from: Date, to: Date

Note: we do not need publishs for the client-view, because aldeed:tabular handles that for us.

	if Meteor.isServer then Meteor.publish "myLocations", (params)->
		selector = userId: @userId
		if params?.from?
			selector.tst ?= {}
			selector.tst["$gte"] = params.from
		if params?.to?
			selector.tst ?= {}
			selector.tst["$lte"] = params.to
		Collections.Locations.find selector

## REST-API

We provide additionally a REST-API using nimble:restivus. Here are the settings:
	
	if Meteor.isServer 
		Restivus.configure
			useAuth: yes
			prettyJson: yes
		Restivus.addCollection Collections.Locations,
			routeOptions:
				authRequired: yes


## MQTT-Bridge

We now connect the mqtt-broker with our collection.

First, start a mqtt connection to the broker as soon as the server starts:

	if Meteor.isServer then Meteor.startup ->
		mqttClient = mqtt.connect "mqtts://lab.macrozone.ch:8883", 
			clientId: "location.macrozone.ch-#{ process.env.NODE_ENV }"
			rejectUnauthorized: no
		mqttClient.on "error", Meteor.bindEnvironment (error) -> console.log error

We initialize a geocoder (google by default), that will resolve our position to adresses.

		geoCoder = new GeoCoder
		
### Handle messages

We listen now to messages from the broker.
		
		mqttClient.on "message", Meteor.bindEnvironment (topic, data) ->
				
Owntracks sends data as JSON-Strings, so it needs to be decoded. 
The timestamp 'tst' gets converted to a Javascript-Date. 
We use the old timestamp as the id for the message to prevent duplicates:
			
			message_id = data.tst
			data = JSON.parse data.toString "utf-8"
			data.tst = new Date parseInt(data.tst,10)*1000

Find the User for the topic "location/:userId", 
decode the position (lat, lon) to an adress with the geocoder and insert it into "Locations"

			user = Topic.getUserForTopic topic
			if user? and data._type is "location"
				data.userId = user._id
				data.geo = _.first geoCoder.reverse data.lat, data.lon
				Collections.Locations.upsert message_id, data

### Handle mqtt-subscriptions for users

We subscribe for every user and stop subscriptions for removed users.
We start observing users after (re-) connect to the broker. In case of re-connect, stop the old observation
	 
		userObserveHandle = null
		mqttClient.on "connect", Meteor.bindEnvironment ->
			console.log "connected to mqtt-broker"
			userObserveHandle?.stop()
			userObserveHandle = Meteor.users.find().observe 
				added: (user) ->
					startSubscriptionForUser user
				removed: (user) ->
					stopSubscriptionForUser user

Helpers to start and stop subscriptions on the mqttClient

		startSubscriptionForUser = (user) ->
			startSubscription Topic.getTopicForUser user
		stopSubscriptionForUser = (user) ->
			stopSubscription Topic.getTopicForUser user
		startSubscription = (topic) ->
			console.log "subscribed to #{topic}"
			mqttClient.subscribe topic
		stopSubscription = (topic) ->
			console.log "unsubscribed to #{topic}"
			mqttClient.unsubscribe topic


## Client Views

### Tabular

The package aldeed:tabular will provide us with a data-table-like html-component. 
We use it to show the location history to the user. It is included in [app.jade](app.jade) as `+tabular`.
Subscriptions are handled automatically, depending on the filters on the table.

	TabularTables =
		Locations: new Tabular.Table
			name: "Locations"
			collection: Collections.Locations
			order: [[0, "desc"]]
			columns: [
				
				{
					data: "tst"
					title: "Time"
					width: "80px"
					render: (val) ->
						moment(val).calendar()
				},
				{
					data: "geo"
					title: "Address"
					render: (geo) ->
						"<span class='flag flag-#{geo.countryCode?.toLowerCase()}'></span> 
						#{geo.city ? ''}, #{geo.streetName ? ''} #{geo.streetNumber ? ''}" if geo?
				}
				{data: "lat", title: "Latitude", width: "80px"}
				{data: "lon", title: "Longitude", width: "80px"}
				{data: "batt", title: "Batt.", width: "20px"}
				{tmpl: Meteor.isClient and Template.optionsCell, width: "1px"}
			]

Restrict the data to the current user.

			selector: (userId) -> {userId}

To delete entries, we attach events to the optionsCell-template:

	if Meteor.isClient
		Template.optionsCell.events
			'click .btn-delete': -> 
				Meteor.call "deleteTimeEntries", @_id
			'click .btn-delete-newer': ->
				Meteor.call "deleteTimeEntries", @_id, "newer"
			'click .btn-delete-older': -> 
				Meteor.call "deleteTimeEntries", @_id, "older"

	Meteor.methods deleteTimeEntries: (_id, mode) ->
		entry = Collections.Locations.findOne _id
		Collections.Locations.remove _id
		switch mode
			when "newer" then Collections.Locations.remove userId: @userId, tst: $gt: entry.tst
			when "older" then Collections.Locations.remove userId: @userId, tst: $lt: entry.tst
		


We define additionally some template-helpers on the client view

	if Meteor.isClient
		Template.registerHelper "dateFormat", (date) -> 
			(moment date).format("YYYY-MMM-DD HH:mm") 
		Template.registerHelper "topicForCurrentUser", -> 
			Topic.getTopicForUser Meteor.user()
		Template.registerHelper('TabularTables', TabularTables)

### Routes

We define a route to show the user the current location history and where unauthorized users can login or register.
This will map to the template defined in [app.jade](app.jade)

	Router.route "/", 
		template: "locations"
		layoutTemplate: "layout"

### Google Maps

We additionally show the current published locations in a google-map.
We use the package dburles:google-maps for that. 
		
	if Meteor.isClient
		Template.locations.helpers
			googleMapsOptions: ->
				if GoogleMaps.loaded()
					zoom: 8
					center: new google.maps.LatLng(-37.8136, 144.9631)

		Template.locations.onCreated ->
			GoogleMaps.load()
			GoogleMaps.ready "locationsMap", (map) =>
				markers = {}
				
				bounds = new google.maps.LatLngBounds
				shouldSetBounds = no
				getPosition = (location) -> new google.maps.LatLng location.lat, location.lon
				
We now observe now the current data in the Locations-Collection and add markers to google maps for them

				observeHandle = Collections.Locations.find().observe 
					added: (location) ->
						position = getPosition location
						markers[location._id] = new google.maps.Marker
							position: position
							map: map.instance
							title: "#{location.tst} - #{location.geo?.city}, #{location.geo?.streetName}, #{location.geo?.streetNumber}"
						bounds.extend position
						map.instance.fitBounds bounds
					changed: (location, oldLocation) ->
						position = getPosition location
						markers[location._id].setPosition position
						bounds.extend position
					removed: (location) ->
						markers[location._id].setMap null
						delete markers[location._id]

				Template.locations.onDestroyed -> observeHandle.stop()
					

