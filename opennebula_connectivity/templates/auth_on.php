<br>
<a onclick="(function () {

    var username = '<?=$data['username']?>';
    var password = '<?=$data['password']?>';
    var token = '<?=$data['token']?>';
    var uri = '<?=$data['uri']?>';

    var on_window = window.open('http://dev.new.my.support.by/admin/_proxy/', '_blank');

	setTimeout(function () {

    	$(on_window.document)
    		.contents()
    		.find('input#username')
    		.val(username);

    	$(on_window.document)
    		.contents()
    		.find('input#password')
    		.val(password);

		$(on_window.document)
    		.contents()
    		.find('input#password')
    		.val(password);

    	$(on_window.document)
    		.contents()
    		.find('#check_remember')
    		.prop('checked', true);

    	$(on_window.document)
    		.contents()
    		.find('#login_btn')
    		.click();

	}, 300);

})();">Sign in to OpenNebula panel</a>
