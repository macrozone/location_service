Template.registerHelper "dateFormat", (date) -> 
	(moment date).format("YYYY-MMM-DD HH:mm") 

Template.registerHelper "topicForCurrentUser", -> 
	Topic.getTopicForUser Meteor.user()