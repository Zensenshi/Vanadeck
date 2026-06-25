package com.zensenshi.vanadeck

import android.app.ActivityOptions
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.hardware.display.DisplayManager
import android.os.Build
import android.provider.DocumentsContract
import android.provider.Settings
import android.view.Display
import android.view.inputmethod.InputMethodManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val CHANNEL = "vanadeck/dual_screen"
  private val OVERLAY_CHANNEL = "vanadeck/overlay"
  private val CALIBRATION_CHANNEL = "vanadeck/calibration"
  private val MACROS_CHANNEL = "vanadeck/macros"
  private val MAPS_CHANNEL = "vanadeck/maps"
  private val SETTINGS_CHANNEL = "vanadeck/settings"
  private val IME_CHANNEL = "vanadeck/ime"
  private val PICK_MAPS_FOLDER_REQUEST = 3401
  private val PICK_RESOURCE_FOLDER_REQUEST = 3402
  private val PICK_BACKGROUND_IMAGE_REQUEST = 3403
  private val EXPORT_MACROS_REQUEST = 3404
  private val IMPORT_MACROS_REQUEST = 3405
  private val PREFS_NAME = "vanadeck"
  private val CALIBRATIONS_KEY = "map_calibrations"
  private val MACROS_KEY = "macros"
  private val MACRO_BOOK_TITLES_KEY = "macro_book_titles"
  private val MAPS_TREE_URI_KEY = "maps_tree_uri"
  private val RESOURCE_TREE_URI_KEY = "resource_tree_uri"
  private val SEED_COLOR_KEY = "seed_color"
  private val THEME_MODE_KEY = "theme_mode"
  private val CHAT_FONT_FAMILY_KEY = "chat_font_family"
  private val CHAT_FONT_SIZE_KEY = "chat_font_size"
  private val BACKGROUND_IMAGE_URI_KEY = "background_image_uri"
  private var pendingMapsFolderResult: MethodChannel.Result? = null
  private var pendingResourceFolderResult: MethodChannel.Result? = null
  private var pendingBackgroundImageResult: MethodChannel.Result? = null
  private var pendingMacroExportResult: MethodChannel.Result? = null
  private var pendingMacroImportResult: MethodChannel.Result? = null
  private var pendingMacroBackupPayload: String? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
      when (call.method) {
        "moveToOtherScreen" -> result.success(moveToOtherScreen())
        else -> result.notImplemented()
      }
    }
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL).setMethodCallHandler { call, result ->
      when (call.method) {
        "isSupported" -> result.success(isOverlaySupported())
        "hasPermission" -> result.success(hasOverlayPermission())
        "requestPermission" -> {
          requestOverlayPermission()
          result.success(null)
        }
        "isRunning" -> result.success(VanaDeckOverlayService.isRunning)
        "lastError" -> result.success(VanaDeckOverlayService.lastError)
        "start" -> result.success(startOverlay(call.arguments as? Map<*, *>))
        "stop" -> result.success(stopOverlay())
        "updateScale" -> {
          updateOverlayScale(call.arguments as? Map<*, *>)
          result.success(null)
        }
        "updateAppearance" -> {
          updateOverlayAppearance(call.arguments as? Map<*, *>)
          result.success(null)
        }
        "updateTabPosition" -> {
          updateOverlayTabPosition(call.arguments as? Map<*, *>)
          result.success(null)
        }
        "updateOverlayTheme" -> {
          updateOverlayTheme(call.arguments as? Map<*, *>)
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALIBRATION_CHANNEL).setMethodCallHandler { call, result ->
      val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
      when (call.method) {
        "loadCalibrations" -> result.success(prefs.getString(CALIBRATIONS_KEY, "{}"))
        "saveCalibrations" -> {
          prefs.edit().putString(CALIBRATIONS_KEY, call.arguments as? String ?: "{}").apply()
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MACROS_CHANNEL).setMethodCallHandler { call, result ->
      val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
      when (call.method) {
        "loadMacros" -> result.success(prefs.getString(MACROS_KEY, "{}"))
        "loadMacroBookTitles" -> result.success(prefs.getString(MACRO_BOOK_TITLES_KEY, "{}"))
        "saveMacros" -> {
          prefs.edit().putString(MACROS_KEY, call.arguments as? String ?: "{}").apply()
          result.success(null)
        }
        "saveMacroBookTitles" -> {
          prefs.edit().putString(MACRO_BOOK_TITLES_KEY, call.arguments as? String ?: "{}").apply()
          result.success(null)
        }
        "exportMacroBackup" -> exportMacroBackup(call.arguments as? String ?: "{}", result)
        "importMacroBackup" -> importMacroBackup(result)
        else -> result.notImplemented()
      }
    }
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MAPS_CHANNEL).setMethodCallHandler { call, result ->
      when (call.method) {
        "pickMapsFolder" -> pickMapsFolder(result)
        "getMapsFolderName" -> result.success(getMapsFolderName())
        "loadMapIni" -> result.success(loadTextFile("map.ini"))
        "listMapImages" -> result.success(listMapImages())
        "loadMapImage" -> {
          val uri = call.arguments as? String
          if (uri == null) {
            result.success(null)
          } else {
            result.success(loadBytes(uri))
          }
        }
        else -> result.notImplemented()
      }
    }
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
      val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
      when (call.method) {
        "loadSeedColor" -> {
          if (prefs.contains(SEED_COLOR_KEY)) {
            result.success(prefs.getInt(SEED_COLOR_KEY, 0))
          } else {
            result.success(null)
          }
        }
        "saveSeedColor" -> {
          prefs.edit().putInt(SEED_COLOR_KEY, (call.arguments as? Number)?.toInt() ?: 0).apply()
          result.success(null)
        }
        "loadThemeMode" -> result.success(prefs.getString(THEME_MODE_KEY, "dark"))
        "saveThemeMode" -> {
          prefs.edit().putString(THEME_MODE_KEY, call.arguments as? String ?: "dark").apply()
          result.success(null)
        }
        "loadChatFontFamily" -> result.success(prefs.getString(CHAT_FONT_FAMILY_KEY, "sans-serif"))
        "saveChatFontFamily" -> {
          prefs.edit().putString(CHAT_FONT_FAMILY_KEY, call.arguments as? String ?: "sans-serif").apply()
          result.success(null)
        }
        "loadChatFontSize" -> result.success(prefs.getFloat(CHAT_FONT_SIZE_KEY, 14.0f).toDouble())
        "saveChatFontSize" -> {
          prefs.edit().putFloat(CHAT_FONT_SIZE_KEY, (call.arguments as? Number)?.toFloat() ?: 14.0f).apply()
          result.success(null)
        }
        "loadSetting" -> {
          val key = call.arguments as? String
          result.success(if (key == null) null else prefs.getString(key, null))
        }
        "saveSetting" -> {
          val args = call.arguments as? Map<*, *>
          val key = args?.get("key") as? String
          val value = args?.get("value") as? String
          if (key != null && value != null) {
            prefs.edit().putString(key, value).apply()
          }
          result.success(null)
        }
        "pickBackgroundImage" -> pickBackgroundImage(result)
        "clearBackgroundImage" -> {
          prefs.edit().remove(BACKGROUND_IMAGE_URI_KEY).apply()
          result.success(null)
        }
        "getBackgroundImageName" -> result.success(getBackgroundImageName())
        "loadBackgroundImageBytes" -> {
          val uri = getBackgroundImageUri()
          if (uri == null) {
            result.success(null)
          } else {
            result.success(loadBytes(uri.toString()))
          }
        }
        "pickResourceFolder" -> pickResourceFolder(result)
        "getResourceFolderName" -> result.success(getResourceFolderName())
        "loadResourceBytes" -> {
          val relativePath = call.arguments as? String
          if (relativePath == null) {
            result.success(null)
          } else {
            result.success(loadResourceBytes(relativePath))
          }
        }
        else -> result.notImplemented()
      }
    }
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IME_CHANNEL).setMethodCallHandler { call, result ->
      when (call.method) {
        "openInputMethodSettings" -> {
          startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS))
          result.success(null)
        }
        "showInputMethodPicker" -> {
          val imm = getSystemService(InputMethodManager::class.java)
          imm?.showInputMethodPicker()
          result.success(null)
        }
        "getStatus" -> result.success(imeStatus())
        else -> result.notImplemented()
      }
    }
  }

  private fun imeStatus(): Map<String, Any> {
    val imm = getSystemService(InputMethodManager::class.java)
    val enabledInputMethods = imm?.enabledInputMethodList ?: emptyList()
    val installedInputMethods = imm?.inputMethodList ?: emptyList()
    val selectedInputMethod = Settings.Secure.getString(
      contentResolver,
      Settings.Secure.DEFAULT_INPUT_METHOD
    ) ?: ""
    val selectedLabel = if (selectedInputMethod.isBlank()) {
      ""
    } else {
      installedInputMethods
        .firstOrNull { inputMethod -> inputMethod.id == selectedInputMethod }
        ?.loadLabel(packageManager)
        ?.toString()
        ?: selectedInputMethod.substringAfterLast('/').ifBlank { selectedInputMethod }
    }
    return mapOf(
      "hasEnabledKeyboards" to enabledInputMethods.isNotEmpty(),
      "selectedKeyboardId" to selectedInputMethod,
      "selectedKeyboardName" to selectedLabel,
    )
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    super.onActivityResult(requestCode, resultCode, data)
    if (requestCode == EXPORT_MACROS_REQUEST) {
      val pendingResult = pendingMacroExportResult
      val payload = pendingMacroBackupPayload
      pendingMacroExportResult = null
      pendingMacroBackupPayload = null

      if (resultCode != Activity.RESULT_OK || data?.data == null || payload == null) {
        pendingResult?.success(false)
        return
      }

      val uri = data.data!!
      val success = try {
        contentResolver.openOutputStream(uri)?.use { stream ->
          stream.write(payload.toByteArray(Charsets.UTF_8))
        }
        true
      } catch (_: Exception) {
        false
      }
      pendingResult?.success(success)
      return
    }

    if (requestCode == IMPORT_MACROS_REQUEST) {
      val pendingResult = pendingMacroImportResult
      pendingMacroImportResult = null

      if (resultCode != Activity.RESULT_OK || data?.data == null) {
        pendingResult?.success(null)
        return
      }

      val uri = data.data!!
      val payload = try {
        contentResolver.openInputStream(uri)?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }
      } catch (_: Exception) {
        null
      }
      pendingResult?.success(payload)
      return
    }

    if (requestCode == PICK_BACKGROUND_IMAGE_REQUEST) {
      val pendingResult = pendingBackgroundImageResult
      pendingBackgroundImageResult = null

      if (resultCode != Activity.RESULT_OK || data?.data == null) {
        pendingResult?.success(false)
        return
      }

      val imageUri = data.data!!
      val flags = data.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION
      contentResolver.takePersistableUriPermission(imageUri, flags)
      getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        .edit()
        .putString(BACKGROUND_IMAGE_URI_KEY, imageUri.toString())
        .apply()
      pendingResult?.success(true)
      return
    }

    if (requestCode == PICK_RESOURCE_FOLDER_REQUEST) {
      val pendingResult = pendingResourceFolderResult
      pendingResourceFolderResult = null

      if (resultCode != Activity.RESULT_OK || data?.data == null) {
        pendingResult?.success(false)
        return
      }

      val treeUri = data.data!!
      val flags = data.flags and
        (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
      contentResolver.takePersistableUriPermission(treeUri, flags)
      getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        .edit()
        .putString(RESOURCE_TREE_URI_KEY, treeUri.toString())
        .apply()
      pendingResult?.success(true)
      return
    }

    if (requestCode != PICK_MAPS_FOLDER_REQUEST) {
      return
    }

    val pendingResult = pendingMapsFolderResult
    pendingMapsFolderResult = null

    if (resultCode != Activity.RESULT_OK || data?.data == null) {
      pendingResult?.success(false)
      return
    }

    val treeUri = data.data!!
    val flags = data.flags and
      (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
    contentResolver.takePersistableUriPermission(treeUri, flags)
    getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
      .edit()
      .putString(MAPS_TREE_URI_KEY, treeUri.toString())
      .apply()
    pendingResult?.success(true)
  }

  private fun moveToOtherScreen(): Boolean {
    val displayManager = getSystemService(DisplayManager::class.java) ?: return false
    val displays = displayManager.displays
    if (displays.size <= 1) {
      return false
    }

    val currentDisplayId = display?.displayId ?: Display.DEFAULT_DISPLAY
    val targetDisplay = displays.firstOrNull { it.displayId != currentDisplayId } ?: return false

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val intent = Intent(this, MainActivity::class.java).apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      }
      val options = ActivityOptions.makeBasic().apply {
        launchDisplayId = targetDisplay.displayId
      }
      startActivity(intent, options.toBundle())
      finish()
      return true
    }

    return false
  }

  private fun isOverlaySupported(): Boolean {
    return Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
  }

  private fun hasOverlayPermission(): Boolean {
    if (!isOverlaySupported()) {
      return false
    }
    return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)
  }

  private fun requestOverlayPermission() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || hasOverlayPermission()) {
      return
    }

    val intent = Intent(
      Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
      Uri.parse("package:$packageName"),
    )
    startActivity(intent)
  }

  private fun startOverlay(arguments: Map<*, *>?): Boolean {
    if (!hasOverlayPermission()) {
      return false
    }

    val scale = (arguments?.get("scale") as? Number)?.toDouble()
      ?: VanaDeckOverlayService.DEFAULT_SCALE
    val appearance = arguments?.get("appearance") as? String
      ?: VanaDeckOverlayService.DEFAULT_APPEARANCE
    val tabPosition = arguments?.get("tabPosition") as? String
      ?: VanaDeckOverlayService.DEFAULT_TAB_POSITION
    val intent = Intent(this, VanaDeckOverlayService::class.java).apply {
      action = VanaDeckOverlayService.ACTION_SHOW
      putExtra(VanaDeckOverlayService.EXTRA_SCALE, scale)
      putExtra(VanaDeckOverlayService.EXTRA_APPEARANCE, appearance)
      putExtra(VanaDeckOverlayService.EXTRA_TAB_POSITION, tabPosition)
      putExtra(VanaDeckOverlayService.EXTRA_DISPLAY_ID, currentDisplayId())
    }
    return try {
      startService(intent)
      true
    } catch (_: Exception) {
      false
    }
  }

  private fun stopOverlay(): Boolean {
    val intent = Intent(this, VanaDeckOverlayService::class.java).apply {
      action = VanaDeckOverlayService.ACTION_STOP
    }
    return try {
      startService(intent)
      true
    } catch (_: Exception) {
      false
    }
  }

  private fun updateOverlayScale(arguments: Map<*, *>?) {
    if (!VanaDeckOverlayService.isRunning) {
      return
    }

    val scale = (arguments?.get("scale") as? Number)?.toDouble()
      ?: VanaDeckOverlayService.DEFAULT_SCALE
    val intent = Intent(this, VanaDeckOverlayService::class.java).apply {
      action = VanaDeckOverlayService.ACTION_UPDATE_SCALE
      putExtra(VanaDeckOverlayService.EXTRA_SCALE, scale)
    }
    try {
      startService(intent)
    } catch (_: Exception) {
    }
  }

  private fun updateOverlayAppearance(arguments: Map<*, *>?) {
    if (!VanaDeckOverlayService.isRunning) {
      return
    }

    val appearance = arguments?.get("appearance") as? String
      ?: VanaDeckOverlayService.DEFAULT_APPEARANCE
    val intent = Intent(this, VanaDeckOverlayService::class.java).apply {
      action = VanaDeckOverlayService.ACTION_UPDATE_APPEARANCE
      putExtra(VanaDeckOverlayService.EXTRA_APPEARANCE, appearance)
    }
    try {
      startService(intent)
    } catch (_: Exception) {
    }
  }

  private fun updateOverlayTabPosition(arguments: Map<*, *>?) {
    if (!VanaDeckOverlayService.isRunning) {
      return
    }

    val tabPosition = arguments?.get("tabPosition") as? String
      ?: VanaDeckOverlayService.DEFAULT_TAB_POSITION
    val intent = Intent(this, VanaDeckOverlayService::class.java).apply {
      action = VanaDeckOverlayService.ACTION_UPDATE_TAB_POSITION
      putExtra(VanaDeckOverlayService.EXTRA_TAB_POSITION, tabPosition)
    }
    try {
      startService(intent)
    } catch (_: Exception) {
    }
  }

  private fun updateOverlayTheme(arguments: Map<*, *>?) {
    if (!VanaDeckOverlayService.isRunning) {
      return
    }

    val intent = Intent(this, VanaDeckOverlayService::class.java).apply {
      action = VanaDeckOverlayService.ACTION_UPDATE_OVERLAY_THEME
      (arguments?.get("iconBarColorStyle") as? String)?.let {
        putExtra(VanaDeckOverlayService.EXTRA_ICON_BAR_COLOR_STYLE, it)
      }
      (arguments?.get("iconBarStartColor") as? Number)?.toInt()?.let {
        putExtra(VanaDeckOverlayService.EXTRA_ICON_BAR_START_COLOR, it)
      }
      (arguments?.get("iconBarEndColor") as? Number)?.toInt()?.let {
        putExtra(VanaDeckOverlayService.EXTRA_ICON_BAR_END_COLOR, it)
      }
      (arguments?.get("buttonColor") as? Number)?.toInt()?.let {
        putExtra(VanaDeckOverlayService.EXTRA_BUTTON_COLOR, it)
      }
      (arguments?.get("buttonTextColor") as? Number)?.toInt()?.let {
        putExtra(VanaDeckOverlayService.EXTRA_BUTTON_TEXT_COLOR, it)
      }
    }
    try {
      startService(intent)
    } catch (_: Exception) {
    }
  }

  private fun currentDisplayId(): Int {
    return display?.displayId ?: Display.DEFAULT_DISPLAY
  }

  private fun pickMapsFolder(result: MethodChannel.Result) {
    if (pendingMapsFolderResult != null) {
      result.error("picker_active", "A maps folder picker is already open.", null)
      return
    }

    pendingMapsFolderResult = result
    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
      addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
      addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
      addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
    }
    startActivityForResult(intent, PICK_MAPS_FOLDER_REQUEST)
  }

  private fun pickResourceFolder(result: MethodChannel.Result) {
    if (pendingResourceFolderResult != null) {
      result.error("picker_active", "A resource folder picker is already open.", null)
      return
    }

    pendingResourceFolderResult = result
    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
      addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
      addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
      addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
    }
    startActivityForResult(intent, PICK_RESOURCE_FOLDER_REQUEST)
  }

  private fun pickBackgroundImage(result: MethodChannel.Result) {
    if (pendingBackgroundImageResult != null) {
      result.error("picker_active", "A background image picker is already open.", null)
      return
    }

    pendingBackgroundImageResult = result
    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
      type = "image/*"
      addCategory(Intent.CATEGORY_OPENABLE)
      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
      addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
    }
    startActivityForResult(intent, PICK_BACKGROUND_IMAGE_REQUEST)
  }

  private fun exportMacroBackup(payload: String, result: MethodChannel.Result) {
    if (pendingMacroExportResult != null) {
      result.error("picker_active", "A macro backup picker is already open.", null)
      return
    }

    pendingMacroExportResult = result
    pendingMacroBackupPayload = payload
    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
      type = "application/json"
      addCategory(Intent.CATEGORY_OPENABLE)
      putExtra(Intent.EXTRA_TITLE, "vanadeck_macros.json")
      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
      addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
    }
    startActivityForResult(intent, EXPORT_MACROS_REQUEST)
  }

  private fun importMacroBackup(result: MethodChannel.Result) {
    if (pendingMacroImportResult != null) {
      result.error("picker_active", "A macro backup picker is already open.", null)
      return
    }

    pendingMacroImportResult = result
    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
      type = "application/json"
      addCategory(Intent.CATEGORY_OPENABLE)
      addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }
    startActivityForResult(intent, IMPORT_MACROS_REQUEST)
  }

  private fun getMapsTreeUri(): Uri? {
    val uri = getSharedPreferences(PREFS_NAME, MODE_PRIVATE).getString(MAPS_TREE_URI_KEY, null)
    return uri?.let { Uri.parse(it) }
  }

  private fun getMapsFolderName(): String? {
    val treeUri = getMapsTreeUri() ?: return null
    return queryDisplayName(treeUri) ?: treeUri.lastPathSegment ?: "Selected Maps folder"
  }

  private fun getResourceTreeUri(): Uri? {
    val uri = getSharedPreferences(PREFS_NAME, MODE_PRIVATE).getString(RESOURCE_TREE_URI_KEY, null)
    return uri?.let { Uri.parse(it) }
  }

  private fun getResourceFolderName(): String? {
    val treeUri = getResourceTreeUri() ?: return null
    return queryDisplayName(treeUri) ?: treeUri.lastPathSegment ?: "Selected resource folder"
  }

  private fun getBackgroundImageUri(): Uri? {
    val uri = getSharedPreferences(PREFS_NAME, MODE_PRIVATE).getString(BACKGROUND_IMAGE_URI_KEY, null)
    return uri?.let { Uri.parse(it) }
  }

  private fun getBackgroundImageName(): String? {
    val uri = getBackgroundImageUri() ?: return null
    return queryDisplayName(uri) ?: uri.lastPathSegment ?: "Selected background image"
  }

  private fun loadTextFile(fileName: String): String? {
    return try {
      val document = findDocument(fileName) ?: return null
      contentResolver.openInputStream(document.uri)?.bufferedReader()?.use { it.readText() }
    } catch (_: Exception) {
      null
    }
  }

  private fun loadBytes(uriString: String): ByteArray? {
    return try {
      contentResolver.openInputStream(Uri.parse(uriString))?.use { it.readBytes() }
    } catch (_: Exception) {
      null
    }
  }

  private fun loadResourceBytes(relativePath: String): ByteArray? {
    return try {
      val parts = relativePath.split('/').filter { it.isNotBlank() }
      if (parts.isEmpty()) {
        return null
      }
      val document = findResourceDocument(parts) ?: return null
      contentResolver.openInputStream(document.uri)?.use { it.readBytes() }
    } catch (_: Exception) {
      null
    }
  }

  private fun findResourceDocument(parts: List<String>): DocumentInfo? {
    val treeUri = getResourceTreeUri() ?: return null
    val rootDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
    val rootUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, rootDocumentId)
    return findResourceDocument(treeUri, rootUri, parts, 0)
  }

  private fun findResourceDocument(
    treeUri: Uri,
    parentUri: Uri,
    parts: List<String>,
    index: Int,
  ): DocumentInfo? {
    for (document in listChildren(treeUri, parentUri)) {
      if (!document.name.equals(parts[index], ignoreCase = true)) {
        continue
      }
      if (index == parts.lastIndex) {
        return document
      }
      if (document.mimeType == DocumentsContract.Document.MIME_TYPE_DIR) {
        return findResourceDocument(treeUri, document.uri, parts, index + 1)
      }
    }
    return null
  }

  private fun listMapImages(): List<Map<String, String>> {
    return try {
      val images = mutableListOf<Map<String, String>>()
      val treeUri = getMapsTreeUri() ?: return images
      val rootDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
      val rootUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, rootDocumentId)
      collectImages(rootUri, images)
      images
    } catch (_: Exception) {
      emptyList()
    }
  }

  private data class DocumentInfo(
    val uri: Uri,
    val name: String,
    val mimeType: String,
  )

  private fun findDocument(fileName: String): DocumentInfo? {
    val treeUri = getMapsTreeUri() ?: return null
    val rootDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
    val rootUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, rootDocumentId)
    return findDocument(rootUri, fileName)
  }

  private fun findDocument(parentUri: Uri, fileName: String): DocumentInfo? {
    for (document in listChildren(parentUri)) {
      if (document.name.equals(fileName, ignoreCase = true)) {
        return document
      }
      if (document.mimeType == DocumentsContract.Document.MIME_TYPE_DIR) {
        val found = findDocument(document.uri, fileName)
        if (found != null) {
          return found
        }
      }
    }
    return null
  }

  private fun collectImages(parentUri: Uri, images: MutableList<Map<String, String>>) {
    for (document in listChildren(parentUri)) {
      if (document.mimeType == DocumentsContract.Document.MIME_TYPE_DIR) {
        collectImages(document.uri, images)
        continue
      }
      val lowerName = document.name.lowercase()
      if (
        lowerName.endsWith(".png") ||
        lowerName.endsWith(".gif") ||
        lowerName.endsWith(".jpg") ||
        lowerName.endsWith(".jpeg")
      ) {
        images.add(mapOf("name" to document.name, "uri" to document.uri.toString()))
      }
    }
  }

  private fun listChildren(parentUri: Uri): List<DocumentInfo> {
    return try {
      val treeUri = getMapsTreeUri() ?: return emptyList()
      listChildren(treeUri, parentUri)
    } catch (_: Exception) {
      emptyList()
    }
  }

  private fun listChildren(treeUri: Uri, parentUri: Uri): List<DocumentInfo> {
    return try {
      val parentDocumentId = DocumentsContract.getDocumentId(parentUri)
      val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentDocumentId)
      val children = mutableListOf<DocumentInfo>()
      contentResolver.query(
        childrenUri,
        arrayOf(
          DocumentsContract.Document.COLUMN_DOCUMENT_ID,
          DocumentsContract.Document.COLUMN_DISPLAY_NAME,
          DocumentsContract.Document.COLUMN_MIME_TYPE,
        ),
        null,
        null,
        null,
      )?.use { cursor ->
        val idIndex = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
        val nameIndex = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
        val mimeIndex = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)
        while (cursor.moveToNext()) {
          val documentId = cursor.getString(idIndex)
          val documentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, documentId)
          children.add(
            DocumentInfo(
              uri = documentUri,
              name = cursor.getString(nameIndex),
              mimeType = cursor.getString(mimeIndex),
            ),
          )
        }
      }
      children
    } catch (_: Exception) {
      emptyList()
    }
  }

  private fun queryDisplayName(uri: Uri): String? {
    return try {
      contentResolver.query(
        uri,
        arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
        null,
        null,
        null,
      )?.use { cursor ->
        if (cursor.moveToFirst()) {
          cursor.getString(0)
        } else {
          null
        }
      }
    } catch (_: Exception) {
      null
    }
  }
}
