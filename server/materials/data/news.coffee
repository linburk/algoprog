import news from "../lib/news"
import newsItem from "../lib/newsItem"

export default allNews = () ->
    return news([
        newsItem("Обсуждение и архив районной олимпиады", String.raw"""
            <p>Я добавил в <a href='/raion_archive.pdf'>архив старых районных олимпиад</a> задачи прошлого года.</p>
            <p>6 декабря в 14:00 состоится дистанционное обсуждение районной олимпиады (в Zoom или т.п.). Информация для подключения будет в телеграм-чате <a href='http://t.me/algoprog_news'>Алгопрог — объявления</a>. Подключитесь к чату заранее.</p>
            <p>См. еще ранее выставленную на сайт <a href='/material/raion_olympiad'>информация про районную олимпиаду</a>.</p>
        """),
        newsItem("Время от времени наблюдается кратковременная недоступность сайта", String.raw"""
            <p>После технических работ (переноса алгопрога на другой хостинг) время от времени наблюдается кратковременная недоступность сайта (в те моменты, когда стартует новая версия кода алгопрога). Я знаю об этой проблеме и изучаю, как ее можно решить. Пока в такой ситуации просто подождите несколько минут. Если у вас из-за такой недоступности возникли проблемы (например, не прошла оплата), напишите мне.</p>
        """),
        newsItem("Про Открытую олимпиаду (заочку)", String.raw"""
            <p>Началась <a href='https://olympiads.ru/zaoch/'>Открытая олимпиада школьников (так называемая Заочка)</a>. Очень известная олимпиада, поступательная, но задачи не самые простые. Рекомендую участвовать всем, у кого уровень 3+.</p>
        """),
        newsItem("Про районную олимпиаду", String.raw"""
            <p>Добавлена <a href='/material/raion_olympiad'>информация про районную олимпиаду</a>.</p>
        """),
        newsItem("Про дистанционные занятия для старших уровней (примерно 3+)", String.raw"""
            <p>Добавлена <a href='/material/ochn_high'>информация про дистанционные занятия для старших школьников</a>.</p>
        """),
        newsItem("Про очные занятия в новом учебном году", String.raw"""
            <p>Я очень надеюсь, что в новом учебном году будут очные занятия (как всегда, для нижегородских школьников), но на данный момент официальная статистика по коронавирусу
            выглядит довольно пугающе, поэтому я не готов организовывать очные занятия. На сайте прекрасно можно заниматься заочно, и на самом деле примерно 80% учеников занимаются
            полностью заочно, поэтому я не вижу абсолютной необходимости делать очные занятия. Очные занятия будут точно не раньше нового года, да и не факт, что раньше весны.</p>
            <p>При этом я готов проводить онлайн-занятия через zoom или другие сервисы видеоконференций, если будут желающие участвовать в таких занятиях. Формат занятий будет как всегда — никаких лекций, вы сами решаете задачи, просто вам будет легче меня спросить о чем-нибудь. Пишите, если вы хотите участвовать в таком занятии, сразу указывайте время, когда вам удобнее. Думаю, если такие занятия будут, то участвовать в них смогут все желающие (не только нижегородские школьники), хотя я буду отдавать приоритет нижегородским школьникам (в первую очередь в плане выбора удобного времени).</p>
            <p>Также проходят <a href='/material/ochn_high'>онлайн-занятия для старших уровней</a>, это особо важно с учетом того, что олимпиадный сезон никто не отменял :) Занятия устроены аналогично тому, как были устроены такие занятия в прошлом году в ННГУ — я готовлю некоторый контест на codeforces, вы будете решаете (в виртуальном режиме, контест будет доступен несколько дней), после чего мы в онлайн-режиме обсуждаем и разбираем задачи и обсуждаем разные олимпиадные новости. Время такого обсуждения можно выбрать; пишите, если вы планируете участвовать и у вас есть пожелания по времени. Это занятия тоже будут доступны для всех желающих, хотя если ваш уровень ниже чем примерно 2В или 3А, то скорее всего вам будет сложно; и опять-таки приоритет будет отдаваться сильным нижегородским школьникам.</p>
        """),
        newsItem("Опрос про алгопрог", String.raw"""
            Ответьте, пожалуйста, <a href="https://docs.google.com/forms/d/e/1FAIpQLSdDXTZ1yMHp_yk3Di5ie4BcI9HXKtnlJ8iyp9iupdX4fezqag/viewform?usp=sf_link">на несколько вопросов</a>. Тем, кто уже отвечал — я там добавил несколько вопросов, можете ответить еще раз.
        """),
    ])
