React = require('react')

import { StaticRouter } from 'react-router'
import { renderToString } from 'react-dom/server';
import { matchPath, Switch, Route } from 'react-router-dom'

import { Provider } from 'react-redux'

import { Helmet } from "react-helmet"

import Routes from '../../client/routes'
import DefaultHelmet from '../../client/components/DefaultHelmet'
import ConnectedNotifications from '../../client/components/ConnectedNotifications'

import createStore from '../../client/redux/store'
import awaitAll from '../../client/lib/awaitAll'

import User from '../models/user'
import logger from '../log'

import ThemeCss from '../../client/components/ThemeCss'

import Cookies from 'universal-cookie'

renderFullPage = (html, data, helmet, linkClientJsCss) ->
    return '
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8" />
            <meta name="yandex-verification" content="4f0059cd93dfb218" />
            <meta name="verification" content="9562bf97c8461c1a2399c3922d2252" />
            ' + helmet.title + '
            <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/font-awesome/4.7.0/css/font-awesome.min.css"/>
            <link rel="stylesheet" href="/server.bundle.css"/>
            ' + linkClientJsCss.client.assets.css.map((css) => '<link rel="stylesheet" href="/' + css + '"/>').join('') + '
            <link rel="stylesheet" href="/react-diff-view.css"/>
            <link rel="stylesheet" href="/testsystems.css"/>
            <link rel="stylesheet" href="/highlight.css"/>
            <link rel="stylesheet" href="/main.css"/>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <script>
                window.__PRELOADED_STATE__ = ' + JSON.stringify(data) + ';
            </script>
            <script type="text/x-mathjax-config">
                MathJax.Hub.Config({
                    extensions: ["tex2jax.js"],
                    jax: ["input/TeX", "output/HTML-CSS"],
                    tex2jax: {
                        inlineMath: [ ["$","$"], ["\\\\(", "\\\\)"] ],
                        displayMath: [ ["$$","$$"], ["\\\\[", "\\\\]"] ],
                        processEscapes: true
                    },
                    "HTML-CSS": { availableFonts: ["TeX"] }
                });
            </script>
            <script type="text/javascript" src="https://cdn.rawgit.com/davidjbradshaw/iframe-resizer/master/js/iframeResizer.contentWindow.min.js"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.0/MathJax.js?config=TeX-MML-AM_CHTML"></script>
            <script src="/highlight.pack.js"></script>
            <script type="text/javascript" src="https://vk.com/js/api/openapi.js?162"></script>
        </head>
        <body>
            <div id="main" style="min-width: 100%; min-height: 100%">' + html + '</div>
            ' + linkClientJsCss.client.assets.js.map((js) => '<script src="/' + js + '" type="text/javascript"></script>').join('') + '
            <!-- Yandex.Metrika counter -->
            <script type="text/javascript" >
            (function(m,e,t,r,i,k,a){m[i]=m[i]||function(){(m[i].a=m[i].a||[]).push(arguments)};
            m[i].l=1*new Date();k=e.createElement(t),a=e.getElementsByTagName(t)[0],k.async=1,k.src=r,a.parentNode.insertBefore(k,a)})
            (window, document, "script", "https://mc.yandex.ru/metrika/tag.js", "ym");

            ym(54702844, "init", {
                    clickmap:true,
                    trackLinks:true,
                    accurateTrackBounce:true,
                    webvisor:true
            });
            </script>
            <noscript><div><img src="https://mc.yandex.ru/watch/54702844" style="position:absolute; left:-9999px;" alt="" /></div></noscript>
            <!-- /Yandex.Metrika counter -->

            <!-- VK Widget -->
            <div id="vk_community_messages"></div>
            <script type="text/javascript">
            VK.Widgets.CommunityMessages("vk_community_messages", 185677091, {disableExpandChatSound: "1",tooltipButtonText: "Есть вопрос?"});
            </script>
        </body>
        </html>'

defaultTheme = (reqCookies) ->
    cookies = new Cookies(reqCookies)
    cookie = cookies.get('theme')
    if cookie
        return cookie
    else
        return "light"

defaultLang = (req) ->
    cookies = new Cookies(req.headers.cookie)
    host = req.hostname
    cookie = cookies.get('lang')
    if cookie
        return cookie
    else if host == "algoprog.org"
        return "en"
    else
        return "ru"

export default renderOnServer = (linkClientJsCss) => (req, res, next) =>
    # https://github.com/HenningM/express-ws/issues/64
    if req.path.includes(".websocket")
        next()
        return
    try
        initialState = 
            data: [
                {data: req.user || {}
                success: true
                updateTime: new Date()
                url: "me"},
                {data: await User.findById(req.user?.userKey())
                success: true
                updateTime: new Date()
                url: "myUser"},
            ],
            clientCookie: req.headers.cookie,
            theme: defaultTheme(req.headers.cookie)
            lang: defaultLang(req)
            needDataPromises: true
        store = createStore(initialState)

        component = undefined
        foundMatch = undefined
        Routes.some((route) ->
            match = matchPath(req.path, route)
            if (match)
                foundMatch = match
                component = route.component
            return match
        )
        if not component
            res.set('Content-Type', 'text/html').status(200).end('')
            return
        element = React.createElement(component, {match: foundMatch})
        context = {}

        # We have already identified the element,
        # but we need StaticRouter for Link to work
        wrappedElement = <Provider store={store}>
                <div>
                    <DefaultHelmet/>
                    <StaticRouter context={context}>
                        {element}
                    </StaticRouter>
                </div>
            </Provider>

        html = renderToString(wrappedElement)
        await awaitAll(store.getState().dataPromises)
        store.getState().needDataPromises = false

        wrappedElement = <Provider store={store}>
                <div>
                    <DefaultHelmet/>
                    <StaticRouter context={context}>
                        <div>
                            <ThemeCss/>
                            {element}
                            <ConnectedNotifications/>
                        </div>
                    </StaticRouter>
                </div>
            </Provider>
        html = renderToString(wrappedElement)

    catch error
        logger.error(error)
        res.status(500).send('Error 500')
        return
    finally
        helmet = Helmet.renderStatic();

    state = store.getState()
    delete state.dataPromises
    delete state.clientCookie

    res.set('Content-Type', 'text/html').status(200).end(renderFullPage(html, state, helmet, linkClientJsCss))
