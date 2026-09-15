{
    catppuccin = {
        extid = "{f5525f34-4102-4f6e-8478-3cf23cfeff7a}";
        version = "1.0";
        url = "https://addons.mozilla.org/firefox/downloads/file/3880040/catppuccin-1.0.xpi";
        sha256 = "d66c9536c4cfa42e68d5f1b0ff54ec7e78f937313495f116cbc8c728355121f8";
    };
    darkreader = {
        extid = "addon@darkreader.org";
        version = "4.9.130";
        url = "https://addons.mozilla.org/firefox/downloads/file/4998573/darkreader-4.9.130.xpi";
        sha256 = "075d5457316af21d62a39a290b31fbf71f514dfc8c3f6a87376fd50f54ef4c9c";
    };
    dearrow = {
        extid = "deArrow@ajay.app";
        version = "2.3.10";
        url = "https://addons.mozilla.org/firefox/downloads/file/4897568/dearrow-2.3.10.xpi";
        sha256 = "3151a51db8093746be646c041af3ead553e5de95fa4ebd5fae033e039e1056d1";
    };
    enhancer-for-youtube = {
        extid = "enhancerforyoutube@maximerf.addons.mozilla.org";
        version = "2.0.136";
        url = "https://addons.mozilla.org/firefox/downloads/file/4933627/enhancer_for_youtube-2.0.136.xpi";
        sha256 = "38a0420804d08224fc44e838aec432e947eb688b1300f423eeecbb44d33037fa";
    };
    facebook-container = {
        extid = "@contain-facebook";
        version = "2.3.12";
        url = "https://addons.mozilla.org/firefox/downloads/file/4451874/facebook_container-2.3.12.xpi";
        sha256 = "3369bd865877860e6d7d38399d5902b300d3d5737acb2d1342ff5beb1d3780c1";
    };
    multi-account-containers = {
        extid = "@testpilot-containers";
        version = "8.3.8";
        url = "https://addons.mozilla.org/firefox/downloads/file/4867303/multi_account_containers-8.3.8.xpi";
        sha256 = "306a294845363f15a7478e9620b43f91ea1761088727808e2327bfff16c14447";
    };
    onetab = {
        extid = "extension@one-tab.com";
        version = "2.19";
        url = "https://addons.mozilla.org/firefox/downloads/file/4948072/onetab-2.19.xpi";
        sha256 = "3aab9eda39cb7b1cfc0267d2b2732f877f7df7dd44432b6bafd99f77ac4b0b4b";
    };
    redirector = {
        extid = "redirector@einaregilsson.com";
        version = "3.5.3";
        url = "https://addons.mozilla.org/firefox/downloads/file/3535009/redirector-3.5.3.xpi";
        sha256 = "eddbd3d5944e748d0bd6ecb6d9e9cf0e0c02dced6f42db21aab64190e71c0f71";
    };
    sidebery = {
        extid = "{3c078156-979c-498b-8990-85f7987dd929}";
        version = "5.6.1";
        url = "https://addons.mozilla.org/firefox/downloads/file/4903712/sidebery-5.6.1.xpi";
        sha256 = "e8a0a4b556ab7dd536897c1816af9d0918030223068ea6683a04376103a6caf2";
    };
    sponsorblock = {
        extid = "sponsorBlocker@ajay.app";
        version = "6.1.7";
        url = "https://addons.mozilla.org/firefox/downloads/file/4897574/sponsorblock-6.1.7.xpi";
        sha256 = "0d50e1632c6f15ee15a543e670e1c572974605a5c02622916e08e026803df83f";
    };
    ublock-origin = {
        extid = "uBlock0@raymondhill.net";
        version = "1.74.0";
        url = "https://addons.mozilla.org/firefox/downloads/file/4981431/ublock_origin-1.74.0.xpi";
        sha256 = "175756d74468c9ba45863f7fc333d3be670f82d5b066314e915814dd547d1652";
        settings.adminSettings = builtins.fromJSON (builtins.readFile ./ubo-settings.json);
    };
    violentmonkey = {
        extid = "{aecec67f-0d10-4fa7-b7c7-609a2db280cf}";
        version = "2.49.0";
        url = "https://addons.mozilla.org/firefox/downloads/file/5009389/violentmonkey-2.49.0.xpi";
        sha256 = "761ea6a32cee78c3263d19bbd821eafd4ea0722f10ff358ecba2739c5bff76fb";
    };
}
