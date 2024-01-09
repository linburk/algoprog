import news from "../lib/news"
import newsItem from "../lib/newsItem"

export default allNews = () ->
    return news([
        newsItem("10 января занятия в лицее 40 не будет", String.raw"""
            <p>10 января занятия в лицее 40 не будет. 17 января занятие будет как обычно.</p>
        """),

        newsItem("Добавлен телеграм-бот, который оповещает о комментариях", String.raw"""
            Вы теперь можете получать в телеграмме уведомления о зачтенных/проигнорированных решениях, 
            и комментариях. <a href="/material/telegram_bot">Подробнее</a>
        """),

        newsItem("Добавлен чат для учеников алгопрога", String.raw"""
            Добавлен <a href="https://t.me/+Ff0fS3PMo85iNmZi">чат для пользователей алгопрога</a>. 
            Чтобы вступить, надо сначала указать свой телеграм-аккаунт в профиле на алгопроге.
        """),

        newsItem("Опрос про алгопрог", String.raw"""
            Ответьте, пожалуйста, <a href="https://docs.google.com/forms/d/e/1FAIpQLSdDXTZ1yMHp_yk3Di5ie4BcI9HXKtnlJ8iyp9iupdX4fezqag/viewform?usp=sf_link">на несколько вопросов</a>. Тем, кто уже отвечал — я там добавил несколько вопросов, можете ответить еще раз.
        """),
    ])
