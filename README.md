Poll Co-win public API to get the latest info on all the available vaccination centers for a district. Availability will be notified to the configured Telegram channel.

Remember to change the `DISTRICT_ID`. You can get it from inspecting the network traffic in Chrome/Firefox console, while selecting the state/district dropdown in Co-win homepage. 

To get notified set `TELEGRAM_BOT_API_KEY` and `TELEGRAM_CHAT_ID` env and run the script

How to create a Telegram bot? https://core.telegram.org/bots#6-botfather

```
TELEGRAM_BOT_API_KEY=<bot-api-key> TELEGRAM_CHAT_ID=<chat-id> ruby poll_vaccine_telegram.rb
```
