Meteor.startup ->
	mqttClient = mqtt.connect "mqtt://mqtt.macrozone.ch:1883", clientId: "fromServer"
	geoCoder = new GeoCoder

	mqttClient.on "connect", Meteor.bindEnvironment ->
		mqttClient.on "message", Meteor.bindEnvironment (topic, data) ->

			data = JSON.parse data.toString "utf-8"

			data.tst = new Date parseInt(data.tst,10)*1000
			
			user = Meteor.users.findOne locationTopic: topic
	
			if user? and data._type is "location"
				data.userId = user._id
				data.geo = _.first geoCoder.reverse data.lat, data.lon

				Locations.insert data

		mqttClient.on "error", -> console.log arguments

		

	startSubscription = (topic) ->
		console.log "subscribed to #{topic}"
		mqttClient.subscribe topic
	stopSubscription = (topic) ->
		console.log "unsubscribed to #{topic}"
		mqttClient.unsubscribe topic
	
	Meteor.users.find().forEach (user) ->
		if user.locationTopic?
			startSubscription user.locationTopic
	Meteor.users.find().observe 
		added: (doc) ->
			if doc.locationTopic?
				startSubscription doc.locationTopic

		changed: (newDoc, oldDoc) ->
			if oldDoc.locationTopic isnt newDoc.locationTopic
				if oldDoc.locationTopic?
					stopSubscription oldDoc.locationTopic
				if newDoc.locationTopic?
					startSubscription newDoc.locationTopic
		removed: (oldDoc) ->
			if oldDoc.locationTopic? 
				stopSubscription oldDoc.locationTopic
		
		
	