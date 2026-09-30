extends RefCounted
## Tiny localisation: English texts are the keys, Russian is looked up when it is selected.
## Voice lines stay English; only subtitles, HUD and notes are translated.

static var lang := "en"

const RU := {
	# HUD
	"Hold RMB: raise camera   |   LMB: shoot   |   Q / E: change lens\nSome things are only visible through the lens.":
		"ПКМ (удерживать): поднять камеру   |   ЛКМ: снимок   |   Q / E: сменить линзу\nНекоторые вещи видны только через объектив.",
	"Find her things. Each one shows up through a different lens.":
		"Найди её вещи. Каждая видна через свою линзу.",
	"Follow her footprints. Only one lens can see them.":
		"Иди по её следам. Их видит только одна линза.",
	"INCOMING CALL\nPress F to answer": "ВХОДЯЩИЙ ЗВОНОК\nНажми F, чтобы ответить",
	"Press G": "Нажми G",
	"YOUR ANSWER": "ТВОЙ ОТВЕТ",
	"Yes": "Да",
	"No": "Нет",
	"CLUE FOUND": "УЛИКА НАЙДЕНА",
	"SPIRIT CAPTURED": "ДУХ ПОЙМАН",
	"Nothing in frame": "В кадре ничего нет",
	"OUT OF FILM - changing roll...": "ПЛЁНКА КОНЧИЛАСЬ - меняю катушку...",
	"New roll loaded": "Новая плёнка заряжена",
	"CALL CONNECTED": "ЗВОНОК ПРИНЯТ",
	"YOU ANSWERED: YES": "ТЫ ОТВЕТИЛ: ДА",
	"YOU ANSWERED: NO": "ТЫ ОТВЕТИЛ: НЕТ",
	"LENS": "ЛИНЗА",
	"FILM": "ПЛЁНКА",
	"SIGNAL": "СИГНАЛ",
	"SPIRITS": "ДУХИ",
	"CLUES": "УЛИКИ",
	"DESTINATION": "ЦЕЛЬ",
	"ECTO": "ЭКТО",
	"THERMAL": "ТЕПЛО",
	"UV": "УФ",
	"NIGHT 1": "НОЧЬ 1",
	"NIGHT 2": "НОЧЬ 2",
	"NIGHT 3": "НОЧЬ 3",
	"THE END": "КОНЕЦ",
	# Night 1
	"You're done with the ghosts?": "Ты закончил с призраками?",
	"Alright, hop in the car.": "Хорошо, садись в машину.",
	"Please don't lie to me.": "Пожалуйста, не лги мне.",
	"Dad, this is my dream.": "Папа, это мой сон.",
	# Night 2
	"You found my things, Dad. Do you remember the night I called you?":
		"Ты нашёл мои вещи, папа. Помнишь ту ночь, когда я тебе звонила?",
	"Then you know I asked you to come get me.": "Значит, ты знаешь, что я просила тебя забрать меня.",
	"You were asleep, Dad. I called three times.": "Ты спал, папа. Я звонила три раза.",
	"Follow my footprints, Dad.": "Иди по моим следам, папа.",
	# Night 3
	"You followed me all the way here. Are you ready to know what happened?":
		"Ты дошёл за мной до самого конца. Ты готов узнать, что случилось?",
	"I got into a car that wasn't yours, Dad.": "Я села в чужую машину, папа.",
	"You can't keep running from this, Dad.": "Ты не можешь вечно от этого бежать, папа.",
	"I'm still waiting for you.": "Я всё ещё жду тебя.",
	# Clues
	"Her Backpack": "Её рюкзак",
	"Her school backpack. The zipper is torn, as if someone pulled it.":
		"Её школьный рюкзак. Молния порвана, будто её дёрнули.",
	"Her Red Coat": "Её красное пальто",
	"Her red coat. It was cold that night.": "Её красное пальто. В ту ночь было холодно.",
	"Her Notebook": "Её блокнот",
	"Her notebook. The last page says: \"Dad, pick up.\"":
		"Её блокнот. На последней странице: «Папа, возьми трубку».",
	"Her Phone": "Её телефон",
	"Her phone. The last three calls were to you.": "Её телефон. Последние три звонка были тебе.",
	"The End of the Road": "Конец дороги",
	"Two headlights in the dark. This is where her footprints stop.":
		"Две фары в темноте. Здесь её следы обрываются.",
	# Spirit names
	"Wandering Spirit": "Блуждающий дух",
	"Moss Maiden": "Дева мха",
	"Hollow Whisper": "Пустой шёпот",
	"Keeper of Pines": "Хранитель сосен",
	"Lost Lantern": "Потерянный фонарь",
	"Her Schoolmate": "Её одноклассник",
	"The Bus Driver": "Водитель автобуса",
	"A Neighbor": "Сосед",
	"Her Teacher": "Её учитель",
	"A Stranger": "Незнакомец",
	"Her Friend": "Её подруга",
	"The Crossing Guard": "Регулировщик на переходе",
	"A Passerby": "Прохожий",
	"The Night Clerk": "Ночной продавец",
	"A Witness": "Свидетель",
}


static func t(text: String) -> String:
	if lang == "ru" and RU.has(text):
		return RU[text]
	return text
