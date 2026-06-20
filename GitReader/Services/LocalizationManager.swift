import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case german = "de"
    case french = "fr"
    case korean = "ko"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .japanese: return "日本語"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .korean: return "한국어"
        }
    }
}

final class LocalizationManager: ObservableObject, @unchecked Sendable {
    static let shared = LocalizationManager()
    
    @AppStorage("hasUserSelectedLanguage") var hasUserSelectedLanguage: Bool = false
    @AppStorage("appLanguage") private var storedLanguage: AppLanguage = .english
    
    @Published var currentLanguage: AppLanguage = .english {
        didSet {
            hasUserSelectedLanguage = true
            storedLanguage = currentLanguage
            // 触发所有订阅者的更新
            objectWillChange.send()
        }
    }
    
    private init() {
        if UserDefaults.standard.bool(forKey: "hasUserSelectedLanguage") {
            // 用户已手动选择语言
            let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
            self.currentLanguage = AppLanguage(rawValue: raw) ?? .english
        } else {
            // 跟随系统语言
            self.currentLanguage = Self.mapSystemLanguage()
        }
    }
    
    static func mapSystemLanguage() -> AppLanguage {
        guard let preferredLanguage = Locale.preferredLanguages.first?.lowercased() else {
            return .english
        }
        
        if preferredLanguage.hasPrefix("zh-hans") {
            return .simplifiedChinese
        } else if preferredLanguage.hasPrefix("zh-hant") || preferredLanguage.hasPrefix("zh-hk") || preferredLanguage.hasPrefix("zh-tw") {
            return .traditionalChinese
        } else if preferredLanguage.hasPrefix("ja") {
            return .japanese
        } else if preferredLanguage.hasPrefix("de") {
            return .german
        } else if preferredLanguage.hasPrefix("fr") {
            return .french
        } else if preferredLanguage.hasPrefix("ko") {
            return .korean
        } else {
            return .english
        }
    }
    
    func localizedString(for key: String) -> String {
        let lang = currentLanguage.rawValue
        guard let dict = translations[key] else {
            return key
        }
        return dict[lang] ?? dict["en"] ?? key
    }
    
    func localizedString(for key: String, arguments: CVarArg...) -> String {
        let format = localizedString(for: key)
        return String(format: format, arguments: arguments)
    }
    
    private let translations: [String: [String: String]] = [
        // App Title / Header
        "git_reader": [
            "en": "Gits Reader",
            "zh-Hans": "Gits Reader",
            "zh-Hant": "Gits Reader",
            "ja": "Gits Reader",
            "de": "Gits Reader",
            "fr": "Gits Reader",
            "ko": "Gits Reader"
        ],
        "connect_repo_subtitle": [
            "en": "Connect Git Repository\nRead Obsidian Notes on Your Phone",
            "zh-Hans": "连接 Git 仓库\n在手机上阅读 Obsidian 笔记",
            "zh-Hant": "連接 Git 倉庫\n在手機上閱讀 Obsidian 筆記",
            "ja": "Gitリポジトリに接続\nスマホでObsidianノートを読む",
            "de": "Git-Repository verbinden\nObsidian-Notizen auf dem Handy lesen",
            "fr": "Connecter le dépôt Git\nLire les notes Obsidian sur votre téléphone",
            "ko": "Git 리포지토리 연결\n휴대폰에서 Obsidian 노트 읽기"
        ],
        
        // Repo Config Form
        "repo_address": [
            "en": "Repository URL",
            "zh-Hans": "仓库地址",
            "zh-Hant": "倉庫地址",
            "ja": "リポジトリURL",
            "de": "Repository-URL",
            "fr": "URL du dépôt",
            "ko": "리포지토리 주소"
        ],
        "pat_token": [
            "en": "Personal Access Token",
            "zh-Hans": "Personal Access Token",
            "zh-Hant": "Personal Access Token",
            "ja": "Personal Access Token",
            "de": "Personal Access Token",
            "fr": "Personal Access Token",
            "ko": "Personal Access Token"
        ],
        "repo_branch": [
            "en": "Branch",
            "zh-Hans": "分支",
            "zh-Hant": "分支",
            "ja": "ブランチ",
            "de": "Branch",
            "fr": "Branche",
            "ko": "브랜치"
        ],
        "connecting": [
            "en": "Connecting...",
            "zh-Hans": "正在连接...",
            "zh-Hant": "正在連接...",
            "ja": "接続中...",
            "de": "Verbinden...",
            "fr": "Connexion...",
            "ko": "연결 중..."
        ],
        "connect_repo": [
            "en": "Connect Repository",
            "zh-Hans": "连接仓库",
            "zh-Hant": "連接倉庫",
            "ja": "リポジトリを接続",
            "de": "Repository verbinden",
            "fr": "Connecter le dépôt",
            "ko": "리포지토리 연결"
        ],
        "security_notice": [
            "en": "Token is only stored in the device Keychain\nRead-only access, will never push any content",
            "zh-Hans": "Token 仅存储在设备 Keychain 中\n仅用于只读访问，不会推送任何内容",
            "zh-Hant": "Token 僅存儲在設備 Keychain 中\n僅用於唯讀訪問，不會推送任何內容",
            "ja": "トークンはデバイスのKeychainにのみ保存されます\n読み取り専用アクセスで、コンテンツをプッシュすることはありません",
            "de": "Token wird nur im Keychain des Geräts gespeichert\nNur Lesezugriff, es wird kein Inhalt gepusht",
            "fr": "Le jeton est uniquement stocké dans le Keychain de l'appareil\nAccès en lecture seule, ne poussera jamais de contenu",
            "ko": "토큰은 기기의 Keychain에만 저장됩니다\n읽기 전용 액세스이며, 어떤 콘텐츠도 푸시하지 않습니다"
        ],
        "repo_connected_success": [
            "en": "Repository connected successfully",
            "zh-Hans": "仓库连接成功",
            "zh-Hant": "倉庫連接成功",
            "ja": "リポジトリの接続に成功しました",
            "de": "Repository erfolgreich verbunden",
            "fr": "Dépôt connecté avec succès",
            "ko": "리포지토리 연결 성공"
        ],
        "connection_failed": [
            "en": "Connection failed",
            "zh-Hans": "连接测试失败",
            "zh-Hant": "連接測試失敗",
            "ja": "接続テストに失敗しました",
            "de": "Verbindungstest fehlgeschlagen",
            "fr": "Échec du test de connexion",
            "ko": "연결 테스트 실패"
        ],
        
        // File List
        "clone_failed": [
            "en": "Failed to clone repository",
            "zh-Hans": "克隆仓库失败",
            "zh-Hant": "克隆倉庫失敗",
            "ja": "リポジトリのクローンに失敗しました",
            "de": "Klonen des Repositorys fehlgeschlagen",
            "fr": "Échec du clonage du dépôt",
            "ko": "리포지토리 클론 실패"
        ],
        "clone_failed_desc": [
            "en": "%@\n\nPlease check your network or modify configuration in Settings",
            "zh-Hans": "%@\n\n请检查网络或在设置中修改配置",
            "zh-Hant": "%@\n\n請檢查網路或在設置中修改配置",
            "ja": "%@\n\nネットワークを確認するか、設定で構成を変更してください",
            "de": "%@\n\nBitte überprüfen Sie Ihr Netzwerk oder ändern Sie die Konfiguration in den Einstellungen",
            "fr": "%@\n\nVeuillez vérifier votre réseau ou modifier la configuration dans les Paramètres",
            "ko": "%@\n\n네트워크를 확인하거나 설정에서 구성을 수정하십시오"
        ],
        "retry_clone": [
            "en": "Retry Clone",
            "zh-Hans": "重试克隆",
            "zh-Hant": "重試克隆",
            "ja": "クローンを再試行",
            "de": "Klonen wiederholen",
            "fr": "Réessayer le clonage",
            "ko": "클론 재시도"
        ],
        "no_matching_notes": [
            "en": "No matching notes found",
            "zh-Hans": "没有找到匹配的笔记",
            "zh-Hant": "沒有找到匹配的筆記",
            "ja": "一致するノートが見つかりません",
            "de": "Keine passenden Notizen gefunden",
            "fr": "Aucune note correspondante trouvée",
            "ko": "일치하는 노트를 찾을 수 없습니다"
        ],
        "no_matching_notes_desc": [
            "en": "Try other keywords\nor click sync to get the latest content",
            "zh-Hans": "试试其他关键词\n或点击同步获取最新内容",
            "zh-Hant": "試試其他關鍵詞\n或點擊同步獲取最新內容",
            "ja": "他のキーワードを試すか、同期をクリックして最新のコンテンツを取得してください",
            "de": "Versuchen Sie andere Schlüsselwörter\noder klicken Sie auf Synchronisieren, um die neuesten Inhalte zu erhalten",
            "fr": "Essayez d'autres mots-clés\nou cliquez sur synchroniser pour obtenir le dernier contenu",
            "ko": "다른 키워드를 시도하거나 동기화를 클릭하여 최신 콘텐츠를 가져옵니다"
        ],
        "repo_empty": [
            "en": "Repository is empty",
            "zh-Hans": "仓库为空",
            "zh-Hant": "倉庫為空",
            "ja": "リポジトリが空です",
            "de": "Repository ist leer",
            "fr": "Le dépôt est vide",
            "ko": "리포지토리가 비어 있습니다"
        ],
        "repo_empty_desc": [
            "en": "Click the sync button in the top right\nto pull the latest content",
            "zh-Hans": "点击右上角同步按钮\n拉取最新内容",
            "zh-Hant": "點擊右上角同步按鈕\n拉取最新內容",
            "ja": "右上隅の同期ボタンをクリックして、最新のコンテンツを取得してください",
            "de": "Klicken Sie oben rechts auf die Schaltfläche Synchronisieren,\num die neuesten Inhalte abzurufen",
            "fr": "Cliquez sur le bouton de synchronisation en haut à droite\npour récupérer le dernier contenu",
            "ko": "최신 콘텐츠를 가져오려면\n오른쪽 상단의 동기화 버튼을 클릭하십시오"
        ],
        "search_notes_placeholder": [
            "en": "Search notes...",
            "zh-Hans": "搜索笔记名...",
            "zh-Hant": "搜尋筆記名...",
            "ja": "ノート名を検索...",
            "de": "Notizen suchen...",
            "fr": "Rechercher des notes...",
            "ko": "노트 이름 검색..."
        ],
        "status": [
            "en": "Status",
            "zh-Hans": "状态",
            "zh-Hant": "狀態",
            "ja": "ステータス",
            "de": "Status",
            "fr": "Statut",
            "ko": "상태"
        ],
        "tag": [
            "en": "Tag",
            "zh-Hans": "标签",
            "zh-Hant": "標籤",
            "ja": "タグ",
            "de": "Tag",
            "fr": "Tag",
            "ko": "태그"
        ],
        "clear_filter": [
            "en": "Clear Filters",
            "zh-Hans": "清除筛选",
            "zh-Hant": "清除篩選",
            "ja": "フィルターをクリア",
            "de": "Filter löschen",
            "fr": "Effacer les filtres",
            "ko": "필터 지우기"
        ],
        "root_directory": [
            "en": "📄 Root Directory",
            "zh-Hans": "📄 根目录",
            "zh-Hant": "📄 根目錄",
            "ja": "📄 ルートディレクトリ",
            "de": "📄 Stammverzeichnis",
            "fr": "📄 Répertoire racine",
            "ko": "📄 루트 디렉터리"
        ],
        "select_tag": [
            "en": "Select Tag",
            "zh-Hans": "选择标签",
            "zh-Hant": "選擇標籤",
            "ja": "タグを選択",
            "de": "Tag auswählen",
            "fr": "Sélectionner un tag",
            "ko": "태그 선택"
        ],
        "clear": [
            "en": "Clear",
            "zh-Hans": "清除",
            "zh-Hant": "清除",
            "ja": "クリア",
            "de": "Löschen",
            "fr": "Effacer",
            "ko": "지우기"
        ],
        "search_tags_placeholder": [
            "en": "Search tags...",
            "zh-Hans": "搜索标签...",
            "zh-Hant": "搜尋標籤...",
            "ja": "タグを検索...",
            "de": "Tags suchen...",
            "fr": "Rechercher des tags...",
            "ko": "태그 검색..."
        ],
        "no_matching_tags": [
            "en": "No matching tags",
            "zh-Hans": "无匹配标签",
            "zh-Hant": "無匹配標籤",
            "ja": "一致するタグがありません",
            "de": "Keine passenden Tags",
            "fr": "Aucun tag correspondant",
            "ko": "일치하는 태그 없음"
        ],
        "select_status": [
            "en": "Select Status",
            "zh-Hans": "选择状态",
            "zh-Hant": "選擇狀態",
            "ja": "ステータスを選択",
            "de": "Status auswählen",
            "fr": "Sélectionner un statut",
            "ko": "상태 선택"
        ],
        "sync_completed": [
            "en": "Sync completed",
            "zh-Hans": "同步完成",
            "zh-Hant": "同步完成",
            "ja": "同期が完了しました",
            "de": "Synchronisierung abgeschlossen",
            "fr": "Synchronisation terminée",
            "ko": "동기화 완료"
        ],
        "sync_failed": [
            "en": "Sync failed: %@",
            "zh-Hans": "同步失败: %@",
            "zh-Hant": "同步失敗: %@",
            "ja": "同期に失敗しました: %@",
            "de": "Synchronisierung fehlgeschlagen: %@",
            "fr": "Échec de la synchronisation : %@",
            "ko": "동기화 실패: %@"
        ],
        "syncing": [
            "en": "Syncing...",
            "zh-Hans": "正在同步...",
            "zh-Hant": "正在同步...",
            "ja": "同期中...",
            "de": "Synchronisieren...",
            "fr": "Synchronisation...",
            "ko": "동기화 중..."
        ],
        "offline_mode": [
            "en": "Offline Mode",
            "zh-Hans": "离线模式",
            "zh-Hant": "離線模式",
            "ja": "オフラインモード",
            "de": "Offline-Modus",
            "fr": "Mode hors ligne",
            "ko": "오프라인 모드"
        ],
        "offline_mode_with_time": [
            "en": "Offline Mode · Data as of %@",
            "zh-Hans": "离线模式 · 数据截至 %@",
            "zh-Hant": "離線模式 · 數據截至 %@",
            "ja": "オフラインモード · %@ 時点のデータ",
            "de": "Offline-Modus · Daten vom %@",
            "fr": "Mode hors ligne · Données au %@",
            "ko": "오프라인 모드 · %@ 기준 데이터"
        ],
        
        // Settings
        "settings": [
            "en": "Settings",
            "zh-Hans": "设置",
            "zh-Hant": "設置",
            "ja": "設定",
            "de": "Einstellungen",
            "fr": "Paramètres",
            "ko": "설정"
        ],
        "repo_info": [
            "en": "Repository Info",
            "zh-Hans": "仓库信息",
            "zh-Hant": "倉庫資訊",
            "ja": "リポジトリ情報",
            "de": "Repository-Info",
            "fr": "Infos du dépôt",
            "ko": "리포지토리 정보"
        ],
        "branch": [
            "en": "Branch",
            "zh-Hans": "分支",
            "zh-Hant": "分支",
            "ja": "ブランチ",
            "de": "Branch",
            "fr": "Branche",
            "ko": "브랜치"
        ],
        "sync_now": [
            "en": "Sync Now",
            "zh-Hans": "立即同步",
            "zh-Hant": "立即同步",
            "ja": "今すぐ同期",
            "de": "Jetzt synchronisieren",
            "fr": "Synchroniser maintenant",
            "ko": "지금 동기화"
        ],
        "just_updated": [
            "en": "Just updated",
            "zh-Hans": "刚刚更新",
            "zh-Hant": "剛剛更新",
            "ja": "今更新した",
            "de": "Gerade aktualisiert",
            "fr": "Mis à jour à l'instant",
            "ko": "방금 업데이트됨"
        ],
        "property_template_management": [
            "en": "Metadata Template",
            "zh-Hans": "元数据模板管理",
            "zh-Hant": "元數據模板管理",
            "ja": "メタデータテンプレート管理",
            "de": "Metadaten-Vorlage",
            "fr": "Modèle de métadonnées",
            "ko": "메타데이터 템플릿 관리"
        ],
        "disconnect_repo": [
            "en": "Disconnect Repository",
            "zh-Hans": "断开仓库连接",
            "zh-Hant": "斷開倉庫連接",
            "ja": "リポジトリの接続を解除",
            "de": "Repository-Verbindung trennen",
            "fr": "Déconnecter le dépôt",
            "ko": "리포지토리 연결 해제"
        ],
        "about": [
            "en": "About",
            "zh-Hans": "关于",
            "zh-Hant": "關於",
            "ja": "情報",
            "de": "Über",
            "fr": "À propos",
            "ko": "정보"
        ],
        "cancel": [
            "en": "Cancel",
            "zh-Hans": "取消",
            "zh-Hant": "取消",
            "ja": "キャンセル",
            "de": "Abbrechen",
            "fr": "Annuler",
            "ko": "취소"
        ],
        "disconnect": [
            "en": "Disconnect",
            "zh-Hans": "断开",
            "zh-Hant": "斷開",
            "ja": "解除",
            "de": "Trennen",
            "fr": "Déconnecter",
            "ko": "연결 해제"
        ],
        "disconnect_alert_message": [
            "en": "This will clear local cache and saved Token.",
            "zh-Hans": "这将清除本地缓存和保存的 Token。",
            "zh-Hant": "這將清除本地緩存和保存的 Token。",
            "ja": "これにより、ローカルキャッシュと保存されたトークンがクリアされます。",
            "de": "Dadurch werden der lokale Cache und das gespeicherte Token gelöscht.",
            "fr": "Cela effacera le cache local et le jeton enregistré.",
            "ko": "이렇게 하면 로컬 캐시와 저장된 토큰이 지워집니다."
        ],
        "disconnected_success": [
            "en": "Disconnected successfully",
            "zh-Hans": "已断开仓库连接",
            "zh-Hant": "已斷開倉庫連接",
            "ja": "リポジトリの接続を解除しました",
            "de": "Repository-Verbindung erfolgreich getrennt",
            "fr": "Dépôt déconnecté avec succès",
            "ko": "리포지토리 연결이 해제되었습니다"
        ],
        "language": [
            "en": "Language",
            "zh-Hans": "语言",
            "zh-Hant": "語言",
            "ja": "言語",
            "de": "Sprache",
            "fr": "Langue",
            "ko": "언어"
        ],
        
        // Property Template Settings
        "yaml_template": [
            "en": "YAML Template",
            "zh-Hans": "YAML 模板",
            "zh-Hant": "YAML 模板",
            "ja": "YAMLテンプレート",
            "de": "YAML-Vorlage",
            "fr": "Modèle YAML",
            "ko": "YAML 템플릿"
        ],
        "yaml_template_tip": [
            "en": "Tip: Supported types include: date, enum, tags, text",
            "zh-Hans": "提示：支持的类型 (type) 包括：date (日期), enum (单选), tags (标签), text (单行文本)",
            "zh-Hant": "提示：支援的類型 (type) 包括：date (日期), enum (單選), tags (標籤), text (單行文本)",
            "ja": "ヒント：サポートされているタイプには、date（日付）、enum（単一選択）、tags（タグ）、text（テキスト）があります",
            "de": "Tipp: Unterstützte Typen sind: date (Datum), enum (Auswahl), tags (Tags), text (Text)",
            "fr": "Astuce : Les types pris en charge incluent : date, enum, tags, text",
            "ko": "팁: 지원되는 유형에는 date(날짜), enum(단일 선택), tags(태그), text(텍스트)가 있습니다"
        ],
        "format_error": [
            "en": "Format Error",
            "zh-Hans": "格式错误",
            "zh-Hant": "格式錯誤",
            "ja": "フォーマットエラー",
            "de": "Formatfehler",
            "fr": "Erreur de format",
            "ko": "형식 오류"
        ],
        "preview": [
            "en": "Preview",
            "zh-Hans": "预览",
            "zh-Hant": "預覽",
            "ja": "プレビュー",
            "de": "Vorschau",
            "fr": "Aperçu",
            "ko": "미리보기"
        ],
        
        // Note Reader
        "font_size": [
            "en": "Font Size",
            "zh-Hans": "字体大小",
            "zh-Hant": "字體大小",
            "ja": "フォントサイズ",
            "de": "Schriftgröße",
            "fr": "Taille de police",
            "ko": "글꼴 크기"
        ],
        "font_size_small": [
            "en": "Small",
            "zh-Hans": "小",
            "zh-Hant": "小",
            "ja": "小",
            "de": "Klein",
            "fr": "Petit",
            "ko": "작게"
        ],
        "font_size_medium": [
            "en": "Medium",
            "zh-Hans": "中",
            "zh-Hant": "中",
            "ja": "中",
            "de": "Mittel",
            "fr": "Moyen",
            "ko": "보통"
        ],
        "font_size_large": [
            "en": "Large",
            "zh-Hans": "大",
            "zh-Hant": "大",
            "ja": "大",
            "de": "Groß",
            "fr": "Grand",
            "ko": "크게"
        ],
        "set_properties": [
            "en": "Set Metadata",
            "zh-Hans": "设置元数据",
            "zh-Hant": "設置元數據",
            "ja": "メタデータを設定",
            "de": "Metadaten festlegen",
            "fr": "Définir les métadonnées",
            "ko": "메타데이터 설정"
        ],
        "copy_source": [
            "en": "Copy Source",
            "zh-Hans": "拷贝原文",
            "zh-Hant": "拷貝原文",
            "ja": "原文をコピー",
            "de": "Quelle kopieren",
            "fr": "Copier la source",
            "ko": "원본 복사"
        ],
        "generating": [
            "en": "Generating...",
            "zh-Hans": "正在生成...",
            "zh-Hant": "正在生成...",
            "ja": "生成中...",
            "de": "Generieren...",
            "fr": "Génération...",
            "ko": "생성 중..."
        ],
        "note_not_found": [
            "en": "Note \"%@\" not found",
            "zh-Hans": "未找到笔记 \"%@\"",
            "zh-Hant": "未找到筆記 \"%@\"",
            "ja": "ノート \"%@\" が見つかりません",
            "de": "Notiz \"%@\" nicht gefunden",
            "fr": "Note \"%@\" non trouvée",
            "ko": "노트 \"%@\"을(를) 찾을 수 없습니다"
        ],
        "metadata": [
            "en": "Metadata",
            "zh-Hans": "元数据 (Metadata)",
            "zh-Hant": "元數據 (Metadata)",
            "ja": "メタデータ (Metadata)",
            "de": "Metadaten (Metadata)",
            "fr": "Métadonnées (Metadata)",
            "ko": "메타데이터 (Metadata)"
        ],
        "tags": [
            "en": "Tags",
            "zh-Hans": "Tags",
            "zh-Hant": "Tags",
            "ja": "Tags",
            "de": "Tags",
            "fr": "Tags",
            "ko": "Tags"
        ],
        "updated": [
            "en": "Updated",
            "zh-Hans": "Updated",
            "zh-Hant": "Updated",
            "ja": "Updated",
            "de": "Updated",
            "fr": "Updated",
            "ko": "Updated"
        ],
        "copied_to_clipboard": [
            "en": "Copied to clipboard",
            "zh-Hans": "原文已拷贝到剪贴板",
            "zh-Hant": "原文已拷貝到剪貼板",
            "ja": "クリップボードにコピーしました",
            "de": "In die Zwischenablage kopiert",
            "fr": "Copié dans le presse-papiers",
            "ko": "클립보드에 복사되었습니다"
        ],
        "generate_image_failed": [
            "en": "Failed to generate image",
            "zh-Hans": "生成长图失败",
            "zh-Hant": "生成長圖失敗",
            "ja": "画像の生成に失敗しました",
            "de": "Bildgenerierung fehlgeschlagen",
            "fr": "Échec de la génération de l'image",
            "ko": "이미지 생성 실패"
        ],
        "generate_pdf_failed": [
            "en": "Failed to generate PDF",
            "zh-Hans": "生成 PDF 失败",
            "zh-Hant": "生成 PDF 失敗",
            "ja": "PDFの生成に失敗しました",
            "de": "PDF-Generierung fehlgeschlagen",
            "fr": "Échec de la génération du PDF",
            "ko": "PDF 생성 실패"
        ],
        "properties_updated": [
            "en": "Metadata updated",
            "zh-Hans": "元数据已更新",
            "zh-Hant": "元數據已更新",
            "ja": "メタデータが更新されました",
            "de": "Metadaten aktualisiert",
            "fr": "Métadonnées mises à jour",
            "ko": "메타데이터가 업데이트되었습니다"
        ],
        "sync_committing": [
            "en": "Committing local changes...",
            "zh-Hans": "正在提交本地修改...",
            "zh-Hant": "正在提交本地修改...",
            "ja": "ローカルの変更をコミット中...",
            "de": "Lokale Änderungen werden übertragen...",
            "fr": "Validation des modifications locales...",
            "ko": "로컬 변경 사항 커밋 중..."
        ],
        "sync_pulling": [
            "en": "Pulling remote updates...",
            "zh-Hans": "正在拉取远程更新...",
            "zh-Hant": "正在拉取遠端更新...",
            "ja": "リモートの更新を取得中...",
            "de": "Remote-Updates werden abgerufen...",
            "fr": "Récupération des mises à jour distantes...",
            "ko": "원격 업데이트 가져오는 중..."
        ],
        "sync_resolving_conflicts": [
            "en": "Resolving conflicts (local first)...",
            "zh-Hans": "正在解决冲突（本地优先）...",
            "zh-Hant": "正在解決衝突（本地優先）...",
            "ja": "競合を解決中（ローカル優先）...",
            "de": "Konflikte werden gelöst (lokal bevorzugt)...",
            "fr": "Résolution des conflits (local en priorité)...",
            "ko": "충돌 해결 중 (로컬 우선)..."
        ],
        "sync_pushing": [
            "en": "Pushing to cloud...",
            "zh-Hans": "正在推送至云端...",
            "zh-Hant": "正在推送至雲端...",
            "ja": "クラウドにプッシュ中...",
            "de": "In die Cloud übertragen...",
            "fr": "Envoi vers le cloud...",
            "ko": "클라우드로 푸시 중..."
        ],
        "sync_success": [
            "en": "Sync completed successfully!",
            "zh-Hans": "同步成功！",
            "zh-Hant": "同步成功！",
            "ja": "同期が正常に完了しました！",
            "de": "Synchronisierung erfolgreich abgeschlossen!",
            "fr": "Synchronisation réussie !",
            "ko": "동기화가 성공적으로 완료되었습니다!"
        ],
        "sync_failed_detail": [
            "en": "Sync failed: %@",
            "zh-Hans": "同步失败: %@",
            "zh-Hant": "同步失敗: %@",
            "ja": "同期に失敗しました: %@",
            "de": "Synchronisierung fehlgeschlagen: %@",
            "fr": "Échec de la synchronisation : %@",
            "ko": "동기화 실패: %@"
        ],
        "save_properties_failed": [
            "en": "Failed to save metadata: %@",
            "zh-Hans": "保存元数据失败: %@",
            "zh-Hant": "保存元數據失敗: %@",
            "ja": "メタデータの保存に失敗しました: %@",
            "de": "Speichern der Metadaten fehlgeschlagen: %@",
            "fr": "Échec de l'enregistrement des métadonnées : %@",
            "ko": "메타데이터 저장 실패: %@"
        ],
        "read_file_failed": [
            "en": "Failed to read file",
            "zh-Hans": "读取文件失败",
            "zh-Hant": "讀取文件失敗",
            "ja": "ファイルの読み込みに失敗しました",
            "de": "Datei konnte nicht gelesen werden",
            "fr": "Échec de la lecture du fichier",
            "ko": "파일 읽기 실패"
        ],
        "image_load_failed": [
            "en": "Failed to load image",
            "zh-Hans": "图片加载失败",
            "zh-Hant": "圖片載入失敗",
            "ja": "画像の読み込みに失敗しました",
            "de": "Bild konnte nicht geladen werden",
            "fr": "Échec du chargement de l'image",
            "ko": "이미지 로드 실패"
        ],
        "loading_image": [
            "en": "Loading image...",
            "zh-Hans": "正在加载图片...",
            "zh-Hant": "正在載入圖片...",
            "ja": "画像を読み込み中...",
            "de": "Bild wird geladen...",
            "fr": "Chargement de l'image...",
            "ko": "이미지 로드 중..."
        ],
        "image_load_failed_desc": [
            "en": "Please check your network connection or image URL",
            "zh-Hans": "请检查网络连接或图片链接是否正确",
            "zh-Hant": "請檢查網路連線或圖片連結是否正確",
            "ja": "ネットワーク接続または画像URLを確認してください",
            "de": "Bitte überprüfen Sie Ihre Netzwerkverbindung oder Bild-URL",
            "fr": "Veuillez vérifier votre connexion réseau ou l'URL de l'image",
            "ko": "네트워크 연결 또는 이미지 URL을 확인하십시오"
        ],
        "select_date": [
            "en": "Select Date",
            "zh-Hans": "选择日期",
            "zh-Hant": "選擇日期",
            "ja": "日付を選択",
            "de": "Datum auswählen",
            "fr": "Sélectionner une date",
            "ko": "날짜 선택"
        ],
        "please_select": [
            "en": "Please Select",
            "zh-Hans": "请选择",
            "zh-Hant": "請選擇",
            "ja": "選択してください",
            "de": "Bitte auswählen",
            "fr": "Veuillez sélectionner",
            "ko": "선택하십시오"
        ],
        "clear_selection": [
            "en": "Clear Selection",
            "zh-Hans": "清除选择",
            "zh-Hant": "清除選擇",
            "ja": "選択をクリア",
            "de": "Auswahl löschen",
            "fr": "Effacer la sélection",
            "ko": "선택 지우기"
        ],
        "input_new_tag": [
            "en": "Enter new tag...",
            "zh-Hans": "输入新标签...",
            "zh-Hant": "輸入新標籤...",
            "ja": "新しいタグを入力...",
            "de": "Neuen Tag eingeben...",
            "fr": "Saisir un nouveau tag...",
            "ko": "새 태그 입력..."
        ],
        "add": [
            "en": "Add",
            "zh-Hans": "添加",
            "zh-Hant": "添加",
            "ja": "追加",
            "de": "Hinzufügen",
            "fr": "Ajouter",
            "ko": "추가"
        ],
        "input_content": [
            "en": "Enter content",
            "zh-Hans": "输入内容",
            "zh-Hant": "輸入內容",
            "ja": "コンテンツを入力",
            "de": "Inhalt eingeben",
            "fr": "Saisir le contenu",
            "ko": "내용 입력"
        ],
        "save": [
            "en": "Save",
            "zh-Hans": "保存",
            "zh-Hant": "保存",
            "ja": "保存",
            "de": "Speichern",
            "fr": "Enregistrer",
            "ko": "저장"
        ],
        "options": [
            "en": "Options",
            "zh-Hans": "选项",
            "zh-Hant": "選項",
            "ja": "オプション",
            "de": "Optionen",
            "fr": "Options",
            "ko": "옵션"
        ],
        "keychain_save_failed": [
            "en": "Keychain save failed: %@ (%d)",
            "zh-Hans": "Keychain 存储失败: %@ (%d)",
            "zh-Hant": "Keychain 儲存失敗: %@ (%d)",
            "ja": "Keychainの保存に失敗しました: %@ (%d)",
            "de": "Keychain-Speicherung fehlgeschlagen: %@ (%d)",
            "fr": "Échec de l'enregistrement dans le Keychain : %@ (%d)",
            "ko": "Keychain 저장 실패: %@ (%d)"
        ],
        "token_encoding_failed": [
            "en": "Token encoding failed",
            "zh-Hans": "Token 编码失败",
            "zh-Hant": "Token 編碼失敗",
            "ja": "トークンのエンコードに失敗しました",
            "de": "Token-Codierung fehlgeschlagen",
            "fr": "Échec de l'encodage du jeton",
            "ko": "토큰 인코딩 실패"
        ],
        
        // Sync Errors
        "auth_failed_error": [
            "en": "Authentication failed, please check if your Token is correct",
            "zh-Hans": "认证失败，请检查 Token 是否正确",
            "zh-Hant": "認證失敗，請檢查 Token 是否正確",
            "ja": "認証に失敗しました。トークンが正しいか確認してください",
            "de": "Authentifizierung fehlgeschlagen, bitte überprüfen Sie, ob Ihr Token korrekt ist",
            "fr": "Échec de l'authentification, veuillez vérifier si votre jeton est correct",
            "ko": "인증에 실패했습니다. 토큰이 올바른지 확인하십시오"
        ],
        "network_unreachable_error": [
            "en": "Network unreachable, switched to offline mode",
            "zh-Hans": "网络不可达，已切换到离线模式",
            "zh-Hant": "網路不可達，已切換到離線模式",
            "ja": "ネットワークに接続できません。オフラインモードに切り替えました",
            "de": "Netzwerk nicht erreichbar, in den Offline-Modus gewechselt",
            "fr": "Réseau inaccessible, passage en mode hors ligne",
            "ko": "네트워크에 연결할 수 없어 오프라인 모드로 전환되었습니다"
        ],
        "token_not_found_error": [
            "en": "Access Token not found, please reconnect repository",
            "zh-Hans": "未找到 Access Token，请重新连接仓库",
            "zh-Hant": "未找到 Access Token，請重新連接倉庫",
            "ja": "アクセストークンが見つかりません。リポジトリに再接続してください",
            "de": "Access Token nicht gefunden, bitte verbinden Sie das Repository erneut",
            "fr": "Jeton d'accès non trouvé, veuillez reconnecter le dépôt",
            "ko": "Access Token을 찾을 수 없습니다. 리포지토리를 다시 연결하십시오"
        ],
        "repo_not_configured_error": [
            "en": "Repository URL not configured",
            "zh-Hans": "未配置仓库地址",
            "zh-Hant": "未配置倉庫地址",
            "ja": "リポジトリURLが設定されていません",
            "de": "Repository-URL nicht konfiguriert",
            "fr": "URL du dépôt non configurée",
            "ko": "리포지토리 주소가 구성되지 않았습니다"
        ],
        "local_repo_not_initialized_error": [
            "en": "Local repository not initialized, please wait for clone to complete",
            "zh-Hans": "本地仓库未完成初始化，请等待克隆完成",
            "zh-Hant": "本地倉庫未完成初始化，請等待克隆完成",
            "ja": "ローカルリポジトリが初期化されていません。クローンが完了するまでお待ちください",
            "de": "Lokales Repository nicht initialisiert, bitte warten Sie, bis das Klonen abgeschlossen ist",
            "fr": "Dépôt local non initialisé, veuillez attendre la fin du clonage",
            "ko": "로컬 리포지토리가 초기화되지 않았습니다. 클론이 완료될 때까지 기다려 주십시오"
        ],
        "invalid_repo_url": [
            "en": "Invalid repository URL",
            "zh-Hans": "无效的仓库地址",
            "zh-Hant": "無效的倉庫地址",
            "ja": "無効なリポジトリURL",
            "de": "Ungültige Repository-URL",
            "fr": "URL du dépôt invalide",
            "ko": "유효하지 않은 리포지토리 주소"
        ],
        "cannot_build_test_url": [
            "en": "Cannot build test connection URL",
            "zh-Hans": "无法构建测试连接 URL",
            "zh-Hant": "無法構建測試連接 URL",
            "ja": "テスト接続URLを構築できません",
            "de": "Testverbindungs-URL kann nicht erstellt werden",
            "fr": "Impossible de construire l'URL de test de connexion",
            "ko": "테스트 연결 URL을 생성할 수 없습니다"
        ],
        "invalid_server_response": [
            "en": "Invalid server response",
            "zh-Hans": "无效的服务器响应",
            "zh-Hant": "無效的伺服器回應",
            "ja": "無効なサーバー応答",
            "de": "Ungültige Serverantwort",
            "fr": "Réponse du serveur invalide",
            "ko": "유효하지 않은 서버 응답"
        ],
        "repo_does_not_exist": [
            "en": "Repository does not exist, please check if the URL is correct",
            "zh-Hans": "仓库不存在，请检查地址是否正确",
            "zh-Hant": "倉庫不存在，請檢查地址是否正確",
            "ja": "リポジトリが存在しません。URLが正しいか確認してください",
            "de": "Repository existiert nicht, bitte überprüfen Sie, ob die URL korrekt ist",
            "fr": "Le dépôt n'existe pas, veuillez vérifier si l'URL est correcte",
            "ko": "리포지토리가 존재하지 않습니다. 주소가 올바른지 확인하십시오"
        ],
        "connection_test_failed_with_error": [
            "en": "Connection test failed: %@",
            "zh-Hans": "连接测试失败: %@",
            "zh-Hant": "連接測試失敗: %@",
            "ja": "接続テストに失敗しました: %@",
            "de": "Verbindungstest fehlgeschlagen: %@",
            "fr": "Échec du test de connexion : %@",
            "ko": "연결 테스트 실패: %@"
        ],
        "open_repo_failed": [
            "en": "Failed to open repository: %@",
            "zh-Hans": "打开仓库失败: %@",
            "zh-Hant": "打開倉庫失敗: %@",
            "ja": "リポジトリのオープンに失敗しました: %@",
            "de": "Repository konnte nicht geöffnet werden: %@",
            "fr": "Échec de l'ouverture du dépôt : %@",
            "ko": "리포지토리 열기 실패: %@"
        ],
        "find_origin_failed": [
            "en": "Failed to find origin: %@",
            "zh-Hans": "查找 origin 失败: %@",
            "zh-Hant": "查找 origin 失敗: %@",
            "ja": "originの検索に失敗しました: %@",
            "de": "Origin konnte nicht gefunden werden: %@",
            "fr": "Échec de la recherche de origin : %@",
            "ko": "origin 찾기 실패: %@"
        ],
        "fetch_failed": [
            "en": "Fetch failed: %@",
            "zh-Hans": "Fetch 失败: %@",
            "zh-Hant": "Fetch 失敗: %@",
            "ja": "Fetchに失敗しました: %@",
            "de": "Fetch fehlgeschlagen: %@",
            "fr": "Échec du Fetch : %@",
            "ko": "Fetch 실패: %@"
        ],
        "find_origin_branch_ref_failed": [
            "en": "Cannot find origin/%@ reference: %d",
            "zh-Hans": "无法找到 origin/%@ 引用: %d",
            "zh-Hant": "無法找到 origin/%@ 引用: %d",
            "ja": "origin/%@ 参照が見つかりません: %d",
            "de": "Referenz origin/%@ kann nicht gefunden werden: %d",
            "fr": "Impossible de trouver la référence origin/%@ : %d",
            "ko": "origin/%@ 참조를 찾을 수 없습니다: %d"
        ],
        "find_commit_failed": [
            "en": "Failed to find commit: %d",
            "zh-Hans": "查找 commit 失败: %d",
            "zh-Hant": "查找 commit 失敗: %d",
            "ja": "コミットの検索に失敗しました: %d",
            "de": "Commit konnte nicht gefunden werden: %d",
            "fr": "Échec de la recherche du commit : %d",
            "ko": "커밋 찾기 실패: %d"
        ],
        "reset_failed": [
            "en": "Reset failed: %d",
            "zh-Hans": "Reset 失败: %d",
            "zh-Hant": "Reset 失敗: %d",
            "ja": "リセットに失敗しました: %d",
            "de": "Reset fehlgeschlagen: %d",
            "fr": "Échec du Reset : %d",
            "ko": "리셋 실패: %d"
        ],
        "clone_failed_with_detail": [
            "en": "Clone failed: %@ (code: %d)",
            "zh-Hans": "克隆失败: %@ (code: %d)",
            "zh-Hant": "克隆失敗: %@ (code: %d)",
            "ja": "クローンに失敗しました: %@ (code: %d)",
            "de": "Klonen fehlgeschlagen: %@ (code: %d)",
            "fr": "Échec du clonage : %@ (code: %d)",
            "ko": "클론 실패: %@ (code: %d)"
        ],
        "connection_failed_with_status": [
            "en": "Connection failed, HTTP status code: %d",
            "zh-Hans": "连接失败，HTTP 状态码: %d",
            "zh-Hant": "連接失敗，HTTP 狀態碼: %d",
            "ja": "接続に失敗しました。HTTPステータスコード: %d",
            "de": "Verbindung fehlgeschlagen, HTTP-Statuscode: %d",
            "fr": "Échec de la connexion, code d'état HTTP : %d",
            "ko": "연결 실패, HTTP 상태 코드: %d"
        ],
        "delete_repo": [
            "en": "Delete Repository",
            "zh-Hans": "删除仓库"
        ],
        "repo_info": [
            "en": "Repository Information",
            "zh-Hans": "仓库信息"
        ],
        "auth_account": [
            "en": "Authentication Account",
            "zh-Hans": "认证账号"
        ],
        "select_account": [
            "en": "Select Account",
            "zh-Hans": "选择账号"
        ],
        "public_repo_no_auth": [
            "en": "Public Repository (No Auth)",
            "zh-Hans": "公开仓库 (无需认证)"
        ],
        "add_new_account": [
            "en": "Add New Account",
            "zh-Hans": "添加新账号"
        ],
        "login_new_account": [
            "en": "Login New Account",
            "zh-Hans": "登录新账号"
        ],
        "platform": [
            "en": "Platform",
            "zh-Hans": "平台"
        ],
        "custom_client_id_optional": [
            "en": "Custom Client ID (Optional)",
            "zh-Hans": "自定义 Client ID (可选)"
        ],
        "device_flow_code_prompt": [
            "en": "Please enter the following code on the authorization page:",
            "zh-Hans": "请在授权页面中输入以下验证码："
        ],
        "copy_and_open_browser": [
            "en": "Copy & Open Browser",
            "zh-Hans": "复制并打开浏览器"
        ],
        "waiting_for_auth": [
            "en": "Waiting for authorization...",
            "zh-Hans": "正在等待授权..."
        ],
        "start_login": [
            "en": "Start Login",
            "zh-Hans": "开始登录"
        ],
        "add_repo_title": [
            "en": "Add Repository",
            "zh-Hans": "添加仓库"
        ],
        "cancel": [
            "en": "Cancel",
            "zh-Hans": "取消"
        ],
        "clone": [
            "en": "Clone",
            "zh-Hans": "克隆"
        ],
        "no_accounts_logged_in": [
            "en": "No Accounts Logged In",
            "zh-Hans": "未登录任何账号"
        ],
        "no_accounts_logged_in_desc": [
            "en": "Log in to GitHub or GitLab to access your private repositories.",
            "zh-Hans": "登录 GitHub 或 GitLab 账号以访问您的私有仓库。"
        ],
        "logged_in_accounts": [
            "en": "Logged In Accounts",
            "zh-Hans": "已登录账号"
        ],
        "logout": [
            "en": "Log Out",
            "zh-Hans": "退出登录"
        ],
        "account_management_title": [
            "en": "Account Management",
            "zh-Hans": "账号管理"
        ],
        "done": [
            "en": "Done",
            "zh-Hans": "完成"
        ],
        "select_note_to_read": [
            "en": "Select a Note to Read",
            "zh-Hans": "选择一篇笔记开始阅读"
        ],
        "select_note_to_read_desc": [
            "en": "Choose a note from the file list on the left to display its content here.",
            "zh-Hans": "从左侧文件列表中选择一篇笔记，其内容将在此处展示。"
        ],
        "device_flow_expired": [
            "en": "Authorization code expired. Please try again.",
            "zh-Hans": "授权码已过期，请重试。"
        ],
        "device_flow_access_denied": [
            "en": "Access denied by user.",
            "zh-Hans": "用户拒绝了授权。"
        ],
        "device_flow_invalid_response": [
            "en": "Invalid response from server.",
            "zh-Hans": "服务器返回了无效响应。"
        ]
    ]
}

// MARK: - String Extension for easy localization
extension String {
    var localized: String {
        LocalizationManager.shared.localizedString(for: self)
    }
    
    func localized(arguments: CVarArg...) -> String {
        let format = LocalizationManager.shared.localizedString(for: self)
        return String(format: format, arguments: arguments)
    }
}
