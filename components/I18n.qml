pragma Singleton
import QtQuick
import "Translations.js" as Tr

// UI strings. The code passes the Turkish source string to t(); the table
// for the chosen language (components/Translations.js) gives the text, with
// English as the fallback. Island.qml sets `lang` from the `language` config
// key: "en" (default), "es", "ru", "tr", or "auto" to follow the system.
QtObject {
  id: i18n

  property string lang: "en"

  // Offered in the language picker, in this order.
  readonly property var languages: [
    { code: "en", name: "English" },
    { code: "es", name: "Español" },
    { code: "ru", name: "Русский" },
    { code: "tr", name: "Türkçe" }
  ]
  readonly property var codes: languages.map(l => l.code)

  // Like t(), for a source string that is also used with another meaning
  // elsewhere: the key carries a "|context" suffix that Turkish drops.
  function tc(s) {
    var v = t(s)
    return v === s ? s.split("|")[0] : v
  }

  function t(s) {
    if (lang === "tr") return s
    var table = lang === "es" ? Tr.es : lang === "ru" ? Tr.ru : Tr.en
    var v = table[s]
    if (v === undefined && table !== Tr.en) v = Tr.en[s]
    return v !== undefined ? v : s
  }

  // "3 sessions", "1 session", "5 сессий": a number with its noun in the
  // right form. Russian has three forms (1 / 2–4 / 5+, by the last digits).
  readonly property var nouns: ({
    session: { en: ["session", "sessions"], es: ["sesión", "sesiones"], ru: ["сессия", "сессии", "сессий"], tr: ["oturum"] },
    tool:    { en: ["tool", "tools"], es: ["herramienta", "herramientas"], ru: ["инструмент", "инструмента", "инструментов"], tr: ["araç"] },
    file:    { en: ["file", "files"], es: ["archivo", "archivos"], ru: ["файл", "файла", "файлов"], tr: ["dosya"] },
    item:    { en: ["item", "items"], es: ["elemento", "elementos"], ru: ["элемент", "элемента", "элементов"], tr: ["öğe"] },
    agent:   { en: ["agent", "agents"], es: ["agente", "agentes"], ru: ["агент", "агента", "агентов"], tr: ["ajan"] },
    minute:  { en: ["minute", "minutes"], es: ["minuto", "minutos"], ru: ["минута", "минуты", "минут"], tr: ["dakika"] }
  })
  function count(n, noun) {
    var forms = (nouns[noun] || {})[lang] || (nouns[noun] || {}).en || [noun]
    var form = forms[0]
    if (lang === "ru") {
      var d = n % 10, h = n % 100
      form = d === 1 && h !== 11 ? forms[0] : d >= 2 && d <= 4 && (h < 12 || h > 14) ? forms[1] : forms[2]
    } else if (forms.length > 1 && n !== 1) {
      form = forms[1]
    }
    return n + " " + form
  }

  // Date and number formats that go with the language.
  function localeFor(code) {
    return ({ en: "en_US", es: "es_ES", ru: "ru_RU", tr: "tr_TR" })[code] || "en_US"
  }
}
