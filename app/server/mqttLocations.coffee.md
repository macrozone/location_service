	
	

Start a mqtt connection and initialize a GeoCoder for later use. 

	mqttClient = null

	Meteor.startup ->
		console.log "location.macrozone.ch-#{ process.env.NODE_ENV }"
		mqttClient = mqtt.connect "mqtts://lab.macrozone.ch:8883", 
			clientId: "location.macrozone.ch-#{ process.env.NODE_ENV }"
			rejectUnauthorized:false
		geoCoder = new GeoCoder
		
		mqttClient.on "message", Meteor.bindEnvironment (topic, data) ->
			

The mqttClient received a message from the broker. Owntracks sends data as JSON-Strings [^fnOwntracks], 
so it needs to be decoded. The timestamp 'tst' gets converted to a Javascript-Date
			
			data = JSON.parse data.toString "utf-8"

			data._id = data.tst
			data.tst = new Date parseInt(data.tst,10)*1000

Find the User for the topic "location/:userId"

			user = Topic.getUserForTopic topic
			if user? and data._type is "location"

decode the position (lat, lon) to an adress with a geoCoder-Service (google) and insert it to "Locations"

				data.userId = user._id
				data.geo = _.first geoCoder.reverse data.lat, data.lon
				Locations.upsert data._id, data

		mqttClient.on "error", Meteor.bindEnvironment (error) -> console.log error
	


# we subscribe for every user and stop subscriptions for removed users
	
		mqttClient.on "connect", Meteor.bindEnvironment ->
			console.log "connected to mqtt-broker"
			Meteor.users.find().observe 
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