function validateForm(form) {

for (var i = 0; i<form.elements.length; i++) {
	var myType = form.elements[i].type;
	if(myType == 'text') {
		if(!validateField(form.elements[i].value)) {
			alert("Field contains invalid characters");
			return false;
		}
	}
}

return true;

}

function validateField(string) {

/*  Commented out to allow nulls in all fields
	if(string.length < 1) {
    	return false;
    }
*/

    var Chars = "<>`:~!^()\\";
    for (var i = 0; i < string.length; i++) {
    	if(Chars.indexOf(string.charAt(i)) >= 0) {
        	return false;
        }
    }

	return true;
}

