Router.route "/", 
	template: "locations"
	layoutTemplate: "layout"
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
		getPosition = (location) -> new google.maps.LatLng location.lat, location.lon
		Locations.find().observe 
			added: (location) ->
				position = getPosition location
				markers[location._id] = new google.maps.Marker
					position: position
					map: map.instance
					title: getLocationTitle location
				bounds.extend position
				map.instance.fitBounds bounds
			changed: (location, oldLocation) ->
				position = getPosition location
				markers[location._id].setPosition position
				bounds.extend position
			removed: (location) ->
				markers[location._id].setMap null
				delete markers[location._id]
				