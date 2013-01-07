function error_message(msg) {
	$("#Searching_label").hide();
	$("#error_message").html(msg);
}

$(document).ready(function() {

	$("#go").live('click', function() {
			var search_text = $("#search_field").val().trim();
			if (search_text.length == 0) {
				error_message("Search field should not be empty");
			} else {
				$("#Searching_label").show();
				$("#error_message").html("");
				var jqxhr = $.post("/app/PropertyCross/search_listings", {
						"place_name": search_text
					}, function(data) { });
			}

		});

});