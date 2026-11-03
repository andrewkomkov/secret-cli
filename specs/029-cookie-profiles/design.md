# Design (из баг-репорта владельца): cookie из всех профилей Safari

Это дословный проект изменения. Реализация следует ему.

## Change

- `secret-cookies` читает дефолтный файл и каждый
  `WebsiteDataStore/*/Cookies/Cookies.binarycookies`. Профиль без файла пропускается.
- У каждого cookie есть профиль: `default` или UUID каталога.
- `secret cookie ls` показывает профиль в новой колонке `PROFILE`.
- Флаг `--profile ID` (`ls`, `pull`) читает один профиль.
- Одинаковый cookie в нескольких профилях: `pull` берёт cookie с самой поздней датой протухания.
  Несколько путей или несколько доменов для имени — ошибка (код 3), как раньше.
- Команда хелпера `which` даёт профиль и дату cookie, который отдаёт `value`. `pull` зовёт `which`,
  затем `value --profile`. Так дата и комментарий секрета — из того же cookie, что и значение.
- `secret-cookies path` показывает все файлы: `profile<TAB>file`.

## helper/cookies/main.swift

Шапка и путь:

```swift
// secret-cookies: reads Safari Cookies.binarycookies of all profiles (027). Only `value` prints a value.
//   [--profile ID] list DOMAIN               name<TAB>path<TAB>flags<TAB>expiry<TAB>profile
//   [--profile ID] value DOMAIN NAME [PATH]  the value of one cookie on stdout
//   [--profile ID] which DOMAIN NAME [PATH]  profile<TAB>expiry of the cookie that value gives
//   [--profile ID] path                      profile<TAB>file of each file that is read
// Exit: 1 not found, 3 several match (paths on stderr), 64 usage, 65 bad file, 77 no access.
import Foundation

#if SECRET_TEST
let safariLibrary = ProcessInfo.processInfo.environment["SECRET_TEST_SAFARI"] ?? "/nonexistent"
#else
let safariLibrary = NSHomeDirectory() + "/Library/Containers/com.apple.Safari/Data/Library"
#endif
```

Поле `profile` в `Cookie`. `parse` не меняется:

```swift
struct Cookie {
    var domain: String
    var name: String
    var path: String
    var value: String
    var secure: Bool
    var httpOnly: Bool
    var expiry: Double? // Unix time, nil for a cookie without a date
    var profile = ""
}
```

Список файлов и чтение одного файла заменяют `cookiesPath` и `loadCookies()`:

```swift
struct Store { let profile: String; let path: String }

// Safari keeps the default profile in Cookies/ and each other profile in WebsiteDataStore/<UUID>/.
func stores() -> [Store] {
    var out = [Store(profile: "default", path: safariLibrary + "/Cookies/Cookies.binarycookies")]
    let base = safariLibrary + "/WebKit/WebsiteDataStore"
    do {
        for id in try FileManager.default.contentsOfDirectory(atPath: base).sorted() {
            out.append(Store(profile: id, path: base + "/" + id + "/Cookies/Cookies.binarycookies"))
        }
    } catch let e as NSError where e.code == NSFileReadNoPermissionError {
        fail("no access to \(base)", 77)
    } catch {
        // no WebsiteDataStore: Safari has only the default profile
    }
    return out
}

func load(_ s: Store) -> [Cookie] {
    let fd = open(s.path, O_RDONLY)
    if fd < 0 {
        if errno == ENOENT { return [] }
        if errno == EPERM || errno == EACCES { fail("no access to \(s.path)", 77) }
        fail("cannot open \(s.path): \(String(cString: strerror(errno)))", 1)
    }
    let h = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    var data = Data()
    do { data = try h.readToEnd() ?? Data() } catch {
        let code = (error as NSError).code
        if code == Int(EPERM) || code == Int(EACCES) { fail("no access to \(s.path)", 77) }
        fail("cannot read \(s.path)", 1)
    }
    guard let cookies = parse([UInt8](data)) else { fail("not a Cookies.binarycookies file: \(s.path)", 65) }
    return cookies.map { var c = $0; c.profile = s.profile; return c }
}

func selectedStores(_ profile: String?) -> [Store] {
    let all = stores()
    guard let p = profile else { return all }
    let one = all.filter { $0.profile == p }
    if one.isEmpty { fail("no Safari profile \(clean(p))", 1) }
    return one
}

func allCookies(_ profile: String?) -> [Cookie] {
    selectedStores(profile).flatMap(load)
}
```

Выбор одного cookie для `value` и `which`:

```swift
// The same cookie in several profiles is one site login: the latest expiry is the newest login.
func pick(_ cs: [Cookie], _ domain: String, _ name: String, _ path: String?) -> Cookie {
    let found = cs.filter { matches($0, domain) && $0.name == name && (path == nil || $0.path == path) }
    if found.isEmpty { fail("no cookie \(clean(name)) for \(clean(domain))", 1) }
    var places: [String] = []
    for c in found {
        let p = clean(c.path) + "\t" + clean(c.domain)
        if !places.contains(p) { places.append(p) }
    }
    if places.count > 1 {
        let hint = path == nil ? "give PATH" : "same path in several domains"
        err("secret-cookies: \(places.count) cookies \(clean(name)) for \(clean(domain)), \(hint):")
        for p in places { err("  \(p)") }
        exit(3)
    }
    return found.max { ($0.expiry ?? 0) < ($1.expiry ?? 0) }!
}
```

Команды:

```swift
var args = Array(CommandLine.arguments.dropFirst())
var profile: String? = nil
if args.first == "--profile" {
    guard args.count >= 2 else { fail("--profile needs ID", 64) }
    profile = args[1]
    args.removeFirst(2)
}
switch args.first {
case "list" where args.count == 2:
    for c in allCookies(profile) where matches(c, args[1]) {
        print([clean(c.name), clean(c.path), flagsText(c), dateText(c), clean(c.profile)].joined(separator: "\t"))
    }
case "value" where args.count == 3 || args.count == 4:
    let c = pick(allCookies(profile), args[1], args[2], args.count == 4 ? args[3] : nil)
    FileHandle.standardOutput.write(Data(c.value.utf8))
case "which" where args.count == 3 || args.count == 4:
    let c = pick(allCookies(profile), args[1], args[2], args.count == 4 ? args[3] : nil)
    print([clean(c.profile), dateText(c)].joined(separator: "\t"))
case "path" where args.count == 1:
    for s in selectedStores(profile) { print(s.profile + "\t" + s.path) }
default:
    fail("usage: secret-cookies [--profile ID] list DOMAIN | value DOMAIN NAME [PATH] | which DOMAIN NAME [PATH] | path", 64)
}
```

## bin/secret

`cookies_run`: ошибка хелпера уже называет файл, поэтому второй вызов `path` убран:

```bash
  if [ $rc -eq 77 ]; then
    echo "secret: no access to the Safari cookie files." >&2
    echo "Give Full Disk Access to the app that runs secret (Terminal, iTerm, ...) in System Settings >" >&2
    echo "Privacy & Security > Full Disk Access, then run the command again." >&2
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" >/dev/null 2>&1 || true
    exit 1
  fi
```

`cmd_cookie`:

```bash
cmd_cookie() {
  [ $# -ge 1 ] || die "cookie needs ls or pull"
  local sub="$1"; shift
  case "$sub" in
    ls)
      local popt=() domain=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --profile) [ $# -ge 2 ] || die "--profile needs ID"; popt=(--profile "$2"); shift 2 ;;
          -*) die "cookie ls: unknown option $1" ;;
          *) [ -z "$domain" ] || die "cookie ls: too many arguments"; domain="$1"; shift ;;
        esac
      done
      [ -n "$domain" ] || die "cookie ls needs DOMAIN"
      local rows
      rows="$(cookies_run ${popt[@]+"${popt[@]}"} list "$domain")" || exit $?
      [ -n "$rows" ] || return 0
      { printf 'NAME\tPATH\tFLAGS\tEXPIRY\tPROFILE\n'; printf '%s\n' "$rows"; } |
        awk -F'\t' '{ printf "%-32s %-12s %-16s %-10s %s\n", $1, $2, $3, $4, $5 }'
      ;;
    pull)
      local domain="" cname="" as="" cpath="" have_path=0 popt=()
      while [ $# -gt 0 ]; do
        case "$1" in
          --as) [ $# -ge 2 ] || die "--as needs SECRET"; as="$2"; shift 2 ;;
          --path) [ $# -ge 2 ] || die "--path needs PATH"; cpath="$2"; have_path=1; shift 2 ;;
          --profile) [ $# -ge 2 ] || die "--profile needs ID"; popt=(--profile "$2"); shift 2 ;;
          -*) die "cookie pull: unknown option $1" ;;
          *)
            if [ -z "$domain" ]; then domain="$1"
            elif [ -z "$cname" ]; then cname="$1"
            else die "cookie pull: too many arguments"
            fi
            shift ;;
        esac
      done
      [ -n "$domain" ] && [ -n "$cname" ] || die "cookie pull needs DOMAIN and NAME"
      [ -n "$as" ] || die "cookie pull needs --as SECRET"
      check_name "$as"
      local vargs=("$domain" "$cname") info profile expiry value
      [ $have_path -eq 0 ] || vargs+=("$cpath")
      # which and value read the same profile: the expiry date belongs to the stored value
      info="$(cookies_run ${popt[@]+"${popt[@]}"} which "${vargs[@]}")" || exit $?
      profile="${info%%$'\t'*}"
      expiry="${info#*$'\t'}"
      value="$(cookies_run --profile "$profile" value "${vargs[@]}")" || exit $?
      [ -n "$value" ] || die "the cookie $cname has an empty value"
      local xargs=()
      [ -z "$expiry" ] || [ "$expiry" = - ] || xargs=(-x "$expiry")
      printf '%s' "$value" | cmd_set -c "safari cookie $domain $cname, profile $profile" ${xargs[@]+"${xargs[@]}"} "$as"
      ;;
    *) die "cookie needs ls or pull" ;;
  esac
}
```

Текст usage:

```
  secret cookie ls [--profile ID] DOMAIN
                               list the Safari cookies of DOMAIN in all profiles: name, path,
                               flags, expiry, profile (no values)
  secret cookie pull DOMAIN NAME --as SECRET [--path PATH] [--profile ID]
                               store the value of a Safari cookie as SECRET (comment and expiry
                               set); with several profiles, the cookie that expires last;
                               needs Full Disk Access for Terminal; persistent cookies only
```

## Tests

Тестовая сборка читает `SECRET_TEST_SAFARI` вместо `SECRET_TEST_COOKIES`. Каталог фикстуры имеет
`Cookies/Cookies.binarycookies` и `WebKit/WebsiteDataStore/<UUID>/Cookies/Cookies.binarycookies`.

1. Cookie только в профиле: `ls` показывает его с UUID, `pull` кладёт значение.
2. Один cookie в `default` и в профиле с разными датами. `pull` кладёт значение с поздней датой.
   Ставит эту дату в `-x`.
3. `--profile default` со случаем 2: `pull` кладёт значение из `default`.
4. `--profile` с неизвестным ID: код 1, сообщение `no Safari profile`.
5. Нет каталога `WebsiteDataStore`: результат как в 1.3.0.
6. Каталог профиля без `Cookies.binarycookies`: код 0, результат имеет cookie других профилей.
7. Битый файл в профиле: код 65, сообщение называет файл.
8. Два пути для одного имени в двух профилях: код 3, оба пути на stderr.
9. `path` показывает `default` и каждый UUID.
10. stdout `which` и `path` и комментарий секрета не содержат значения cookie.
