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
このレポだと
```
$ curl http://seo-endaaman-me.herokuapp.com/http://endaaman.me/memo
```
ってするとAjaxで取得されたコンテンツが入った状態で表示されるので、nginxだったらconfにUserAgentとか_escaped_fragment_をチェックした中に

```nginx
    set $protocol 'http://';
    if ($https) {
        set $protocol 'https://';
    }

    set $port ":${server_port}";
    if ($server_port = 80) {
      set $port '';
    }
    if ($server_port = 443) {
      set $port '';
    }
    proxy_pass http://seo-endaaman-me.herokuapp.com/$protocol$host$port$request_uri;
```
みたいに `http://target_host/path/to/content` を `http://seo-endaaman-me.herokuapp.com/http://target_host/path/to/content` って感じ書き換えるようにしてやればいい。
