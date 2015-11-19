# SPA用のSEOサーバーをherokuに構築するやつ

```
$ git clone https://github.com/endaaman/seo-endaaman-me.git
$ vim config.coffee      # hostsWhiteListedを書き換える
$ heroku create <名前>
$ heroku config:add BUILDPACK_URL=https://github.com/stomita/heroku-buildpack-phantomjs.git
$ git commit -am '適当にコミット'
$ git push heroku master

```

https://github.com/stomita/heroku-buildpack-phantomjs を見ながらPhantomJSをherokuに導入


## 使い方とか
UserAgentとか_escaped_fragment_をチェックしてクローラーなら `http://target_host/path/to/content` を `http://seo-endaaman-me.herokuapp.com/http://target_host/path/to/content` って感じ書き換えるようにしてやればいい。

実際に使ってる http://endaaman.me のnginxだとこんな感じになってる。
```nginx

    location / {
        index  /index.html;
        try_files $uri @fallback;
        expires off;
    }

    location @fallback {
        set $prerender 0;
        if ($http_user_agent ~* "googlebot|twitter|facebook|yahoo!|bingbot|msnbot|y!j|hatena|ssk|naverbot") {
            set $prerender 1;
        }
        if ($args ~ "_escaped_fragment_") {
            set $prerender 1;
        }
        if ($uri ~ "\.(js|css|xml|less|png|jpg|jpeg|gif|pdf|doc|txt|ico|rss|zip|mp3|rar|exe|wmv|doc|avi|ppt|mpg|mpeg|tif|wav|mov|psd|ai|xls|mp4|m4a|swf|dat|dmg|iso|flv|m4v|torrent|ttf|woff)") {
            set $prerender 0;
        }

        resolver 8.8.8.8;

        set $protocol 'http://';
        if ($https) {
            set $protocol 'https://';
        }

        # これはデバッグ用
        set $prerender_host '127.0.0.1:3001';
        if ($host = 'endaaman.me') {
            set $prerender_host 'seo-endaaman-me.herokuapp.com';
        }

        if ($prerender = 1) {
            rewrite .* /$protocol$host$request_uri? break;
            proxy_pass http://$prerender_host;
        }
        if ($prerender = 0) {
            rewrite .* /index.html break;
        }
    }


```

`prerender.io`のやつの丸パクリだね。

```
$ curl http://seo-endaaman-me.herokuapp.com/http://endaaman.me/memo
とか
$ curl http://endaaman.me/memo -A Googlebot
とか
$ curl http://endaaman.me/memo?_escaped_fragment_
```
ってするとAjaxで取得されたコンテンツが入った状態で表示されるのが確認できる。
