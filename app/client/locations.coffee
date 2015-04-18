Router.route "/", 
	template: "locations"
	onBeforeAction: ->
		GoogleMaps.load()
		@next()
	waitOn: -> 
		Meteor.subscribe "myLocations", 
			from: moment().startOf("day").weekday(-7).toDate()
			to: moment().endOf("day").toDate()
	data: ->
		locations: -> Locations.find {}, sort: tst: -1
		options: ->
			if GoogleMaps.loaded()
				zoom: 8
				center: new google.maps.LatLng(-37.8136, 144.9631)

getLocationTitle = (location) ->
	"#{location.tst} - #{location.geo?.city}, #{location.geo?.streetName}, #{location.geo?.streetNumber}"
Template.locations.created = ->
	GoogleMaps.ready "locationsMap", (map) =>
		markers = {}
		bounds = new google.maps.LatLngBounds
		shouldSetBounds = no
		@autorun ->
			Locations.find().forEach (location) ->
				position = new google.maps.LatLng location.lat, location.lon
				unless markers[location._id]?
					# is new
					shouldSetBounds = yes
					markers[location._id] = new google.maps.Marker
						position: position
						map: map.instance
						title: getLocationTitle location
				else
					markers[location._id].setPosition position
				bounds.extend position
			if shouldSetBounds
				
				map.instance.fitBounds bounds
				shouldSetBounds = no