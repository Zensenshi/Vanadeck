package com.example.vanadeck

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.provider.DocumentsContract
import android.provider.Settings
import android.util.DisplayMetrics
import android.view.Display
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

class VanaDeckOverlayService : Service() {
  companion object {
    const val ACTION_SHOW = "com.example.vanadeck.overlay.SHOW"
    const val ACTION_STOP = "com.example.vanadeck.overlay.STOP"
    const val ACTION_UPDATE_SCALE = "com.example.vanadeck.overlay.UPDATE_SCALE"
    const val ACTION_UPDATE_APPEARANCE = "com.example.vanadeck.overlay.UPDATE_APPEARANCE"
    const val ACTION_UPDATE_TAB_POSITION = "com.example.vanadeck.overlay.UPDATE_TAB_POSITION"
    const val ACTION_UPDATE_OVERLAY_THEME = "com.example.vanadeck.overlay.UPDATE_OVERLAY_THEME"
    const val EXTRA_SCALE = "scale"
    const val EXTRA_APPEARANCE = "appearance"
    const val EXTRA_TAB_POSITION = "tab_position"
    const val EXTRA_ICON_BAR_COLOR_STYLE = "icon_bar_color_style"
    const val EXTRA_ICON_BAR_START_COLOR = "icon_bar_start_color"
    const val EXTRA_ICON_BAR_END_COLOR = "icon_bar_end_color"
    const val EXTRA_BUTTON_COLOR = "button_color"
    const val EXTRA_BUTTON_TEXT_COLOR = "button_text_color"
    const val EXTRA_DISPLAY_ID = "display_id"
    const val DEFAULT_SCALE = 0.41
    const val DEFAULT_APPEARANCE = "gameGlass"
    const val DEFAULT_TAB_POSITION = "top"
    private const val MIN_SCALE = 0.36
    private const val MAX_SCALE = 0.72
    private const val PREFS_NAME = "vanadeck"
    private const val MAPS_TREE_URI_KEY = "maps_tree_uri"
    private const val OVERLAY_X_KEY = "overlay_x"
    private const val OVERLAY_Y_KEY = "overlay_y"
    private const val GAME_GLASS_APPEARANCE = "gameGlass"
    private const val TOP_TAB_POSITION = "top"
    private const val BOTTOM_TAB_POSITION = "bottom"
    private const val LEFT_TAB_POSITION = "left"
    private const val RIGHT_TAB_POSITION = "right"

    @Volatile
    var isRunning: Boolean = false
      private set

    @Volatile
    var lastError: String? = null
      private set
  }

  private var flutterEngine: FlutterEngine? = null
  private var flutterView: FlutterView? = null
  private var windowContext: Context? = null
  private var windowManager: WindowManager? = null
  private var layoutParams: WindowManager.LayoutParams? = null
  private var overlayChannel: MethodChannel? = null
  private var overlayScale = DEFAULT_SCALE
  private var overlayAppearance = DEFAULT_APPEARANCE
  private var overlayTabPosition = DEFAULT_TAB_POSITION
  private var overlayMinimized = false
  private var keyboardActive = false
  private var restoreOverlayX: Int? = null
  private var restoreOverlayY: Int? = null
  private var displayId = Display.DEFAULT_DISPLAY
  private var dragging = false
  private var dragStartRawX = 0f
  private var dragStartRawY = 0f
  private var dragStartX = 0
  private var dragStartY = 0

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    when (intent?.action) {
      ACTION_STOP -> {
        stopSelf()
        return START_NOT_STICKY
      }
      ACTION_UPDATE_SCALE -> {
        overlayScale = clampScale(intent.getDoubleExtra(EXTRA_SCALE, overlayScale))
        if (flutterView == null) {
          stopSelf()
          return START_NOT_STICKY
        }
        resizeOverlay()
        return START_STICKY
      }
      ACTION_UPDATE_APPEARANCE -> {
        overlayAppearance = normalizeAppearance(
          intent.getStringExtra(EXTRA_APPEARANCE) ?: overlayAppearance,
        )
        updateOverlayAppearance()
        return START_STICKY
      }
      ACTION_UPDATE_TAB_POSITION -> {
        overlayTabPosition = normalizeTabPosition(
          intent.getStringExtra(EXTRA_TAB_POSITION) ?: overlayTabPosition,
        )
        updateOverlayTabPosition()
        return START_STICKY
      }
      ACTION_UPDATE_OVERLAY_THEME -> {
        updateOverlayTheme(
          iconBarColorStyle = intent.getStringExtra(EXTRA_ICON_BAR_COLOR_STYLE),
          iconBarStartColor = optionalIntExtra(intent, EXTRA_ICON_BAR_START_COLOR),
          iconBarEndColor = optionalIntExtra(intent, EXTRA_ICON_BAR_END_COLOR),
          buttonColor = optionalIntExtra(intent, EXTRA_BUTTON_COLOR),
          buttonTextColor = optionalIntExtra(intent, EXTRA_BUTTON_TEXT_COLOR),
        )
        return START_STICKY
      }
      else -> {
        overlayScale = clampScale(intent?.getDoubleExtra(EXTRA_SCALE, DEFAULT_SCALE) ?: DEFAULT_SCALE)
        overlayAppearance = normalizeAppearance(
          intent?.getStringExtra(EXTRA_APPEARANCE) ?: DEFAULT_APPEARANCE,
        )
        overlayTabPosition = normalizeTabPosition(
          intent?.getStringExtra(EXTRA_TAB_POSITION) ?: DEFAULT_TAB_POSITION,
        )
        overlayMinimized = false
        displayId = intent?.getIntExtra(EXTRA_DISPLAY_ID, Display.DEFAULT_DISPLAY)
          ?: Display.DEFAULT_DISPLAY
        showOverlay()
        return START_STICKY
      }
    }
  }

  override fun onDestroy() {
    removeOverlay()
    super.onDestroy()
  }

  private fun showOverlay() {
    if (!canDrawOverlay()) {
      lastError = "Android overlay permission is not enabled."
      stopSelf()
      return
    }

    if (flutterView != null) {
      lastError = null
      resizeOverlay()
      return
    }

    try {
      val context = createOverlayContext(displayId)
      val manager = context.getSystemService(WindowManager::class.java)
      windowContext = context
      windowManager = manager

      val engine = FlutterEngine(context)
      GeneratedPluginRegistrant.registerWith(engine)
      overlayChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "vanadeck/overlay")
      overlayChannel?.setMethodCallHandler { call, result ->
        when (call.method) {
          "isSupported" -> result.success(true)
          "hasPermission" -> result.success(canDrawOverlay())
          "isRunning" -> result.success(isRunning)
          "lastError" -> result.success(lastError)
          "setMinimized" -> {
            val args = call.arguments as? Map<*, *>
            setOverlayMinimized(args?.get("minimized") as? Boolean ?: false)
            resizeOverlay()
            result.success(null)
          }
          "setKeyboardActive" -> {
            val args = call.arguments as? Map<*, *>
            keyboardActive = args?.get("active") as? Boolean ?: false
            updateKeyboardFocus()
            result.success(null)
          }
          "stop" -> {
            stopSelf()
            result.success(true)
          }
          "updateScale" -> {
            val args = call.arguments as? Map<*, *>
            overlayScale = clampScale((args?.get("scale") as? Number)?.toDouble() ?: overlayScale)
            resizeOverlay()
            result.success(null)
          }
          "updateTabPosition" -> {
            val args = call.arguments as? Map<*, *>
            overlayTabPosition = normalizeTabPosition(
              args?.get("tabPosition") as? String ?: overlayTabPosition,
            )
            updateOverlayTabPosition()
            result.success(null)
          }
          else -> result.notImplemented()
        }
      }
      MethodChannel(engine.dartExecutor.binaryMessenger, "vanadeck/settings").setMethodCallHandler { call, result ->
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        when (call.method) {
          "loadSeedColor" -> {
            if (prefs.contains("seed_color")) {
              result.success(prefs.getInt("seed_color", 0))
            } else {
              result.success(null)
            }
          }
          "loadSetting" -> {
            val key = call.arguments as? String
            result.success(if (key == null) null else prefs.getString(key, null))
          }
          else -> result.notImplemented()
        }
      }
      MethodChannel(engine.dartExecutor.binaryMessenger, "vanadeck/maps").setMethodCallHandler { call, result ->
        when (call.method) {
          "getMapsFolderName" -> result.success(getMapsFolderName())
          "loadMapIni" -> result.success(loadTextFile("map.ini"))
          "listMapImages" -> result.success(listMapImages())
          "loadMapImage" -> {
            val uri = call.arguments as? String
            result.success(if (uri == null) null else loadBytes(uri))
          }
          else -> result.notImplemented()
        }
      }
      val loader = FlutterInjector.instance().flutterLoader()
      loader.startInitialization(context)
      loader.ensureInitializationComplete(context, null)
      engine.dartExecutor.executeDartEntrypoint(
        DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "overlayMain"),
      )
      engine.lifecycleChannel.appIsResumed()
      flutterEngine = engine

      val textureView = FlutterTextureView(context)
      textureView.setOpaque(false)
      val view = FlutterView(context, textureView)
      view.attachToFlutterEngine(engine)
      view.setOnTouchListener(::handleOverlayTouch)
      flutterView = view

      val params = buildLayoutParams()
      layoutParams = params
      manager.addView(view, params)
      updateOverlayAppearance()
      lastError = null
      isRunning = true
    } catch (error: Exception) {
      lastError = "Overlay failed to start: ${error.javaClass.simpleName}"
      removeOverlay()
      stopSelf()
    }
  }

  private fun removeOverlay() {
    isRunning = false
    val manager = windowManager
    val view = flutterView
    if (manager != null && view != null) {
      try {
        manager.removeView(view)
      } catch (_: Exception) {
      }
    }

    flutterEngine?.lifecycleChannel?.appIsDetached()
    flutterView?.detachFromFlutterEngine()
    flutterEngine?.destroy()
    flutterView = null
    flutterEngine = null
    overlayChannel = null
    windowManager = null
    windowContext = null
    layoutParams = null
  }

  private fun resizeOverlay() {
    val manager = windowManager ?: return
    val view = flutterView ?: return
    val params = layoutParams ?: return
    val size = calculateOverlaySize()
    params.width = size.first
    params.height = size.second
    applyNativeWindowEffects(params)
    applyKeyboardFocus(params)
    if (overlayMinimized) {
      dockMinimized(params)
    } else {
      restoreOverlayPosition(params)
      clampPosition(params)
    }
    manager.updateViewLayout(view, params)
  }

  private fun buildLayoutParams(): WindowManager.LayoutParams {
    val size = calculateOverlaySize()
    val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
    } else {
      @Suppress("DEPRECATION")
      WindowManager.LayoutParams.TYPE_PHONE
    }
    val params = WindowManager.LayoutParams(
      size.first,
      size.second,
      type,
      WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
      PixelFormat.TRANSLUCENT,
    )
    params.gravity = Gravity.TOP or Gravity.START
    applyNativeWindowEffects(params)
    applyKeyboardFocus(params)

    val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
    if (prefs.contains(OVERLAY_X_KEY) && prefs.contains(OVERLAY_Y_KEY)) {
      params.x = prefs.getInt(OVERLAY_X_KEY, 0)
      params.y = prefs.getInt(OVERLAY_Y_KEY, 0)
      clampPosition(params)
    } else {
      val bounds = displayBounds()
      params.x = max(0, bounds.first - size.first - dp(16))
      params.y = max(0, bounds.second - size.second - dp(16))
    }

    return params
  }

  private fun updateOverlayAppearance() {
    overlayChannel?.invokeMethod("setAppearance", mapOf("appearance" to overlayAppearance))
    val manager = windowManager ?: return
    val view = flutterView ?: return
    val params = layoutParams ?: return
    applyNativeWindowEffects(params)
    applyKeyboardFocus(params)
    manager.updateViewLayout(view, params)
  }

  private fun updateOverlayTabPosition() {
    overlayChannel?.invokeMethod("setTabPosition", mapOf("tabPosition" to overlayTabPosition))
    resizeOverlay()
  }

  private fun updateOverlayTheme(
    iconBarColorStyle: String?,
    iconBarStartColor: Int?,
    iconBarEndColor: Int?,
    buttonColor: Int?,
    buttonTextColor: Int?,
  ) {
    overlayChannel?.invokeMethod(
      "setOverlayTheme",
      mapOf(
        "iconBarColorStyle" to iconBarColorStyle,
        "iconBarStartColor" to iconBarStartColor,
        "iconBarEndColor" to iconBarEndColor,
        "buttonColor" to buttonColor,
        "buttonTextColor" to buttonTextColor,
      ),
    )
  }

  private fun optionalIntExtra(intent: Intent, key: String): Int? {
    return if (intent.hasExtra(key)) intent.getIntExtra(key, 0) else null
  }

  private fun updateKeyboardFocus() {
    val manager = windowManager ?: return
    val view = flutterView ?: return
    val params = layoutParams ?: return
    applyKeyboardFocus(params)
    manager.updateViewLayout(view, params)
  }

  private fun handleOverlayTouch(view: View, event: MotionEvent): Boolean {
    when (event.actionMasked) {
      MotionEvent.ACTION_DOWN -> {
        if (overlayMinimized || !isInDragRegion(view, event)) {
          dragging = false
          return false
        }
        val params = layoutParams ?: return false
        dragging = true
        dragStartRawX = event.rawX
        dragStartRawY = event.rawY
        dragStartX = params.x
        dragStartY = params.y
        return true
      }
      MotionEvent.ACTION_MOVE -> {
        if (!dragging) {
          return false
        }
        val manager = windowManager ?: return true
        val params = layoutParams ?: return true
        params.x = dragStartX + (event.rawX - dragStartRawX).roundToInt()
        params.y = dragStartY + (event.rawY - dragStartRawY).roundToInt()
        clampPosition(params)
        manager.updateViewLayout(view, params)
        return true
      }
      MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
        if (!dragging) {
          return false
        }
        dragging = false
        savePosition()
        return true
      }
    }
    return false
  }

  private fun savePosition() {
    val params = layoutParams ?: return
    getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
      .edit()
      .putInt(OVERLAY_X_KEY, params.x)
      .putInt(OVERLAY_Y_KEY, params.y)
      .apply()
  }

  private fun clampPosition(params: WindowManager.LayoutParams) {
    val bounds = displayBounds()
    params.x = params.x.coerceIn(0, max(0, bounds.first - params.width))
    params.y = params.y.coerceIn(0, max(0, bounds.second - params.height))
  }

  private fun dockMinimized(params: WindowManager.LayoutParams) {
    val bounds = displayBounds()
    val margin = dp(8)
    params.x = max(0, bounds.first - params.width - margin)
    params.y = max(0, bounds.second - params.height - margin)
  }

  private fun restoreOverlayPosition(params: WindowManager.LayoutParams) {
    val x = restoreOverlayX
    val y = restoreOverlayY
    if (x == null || y == null) {
      return
    }

    params.x = x
    params.y = y
    restoreOverlayX = null
    restoreOverlayY = null
  }

  private fun setOverlayMinimized(minimized: Boolean) {
    if (minimized == overlayMinimized) {
      return
    }

    val params = layoutParams
    if (minimized && params != null) {
      restoreOverlayX = params.x
      restoreOverlayY = params.y
    }

    overlayMinimized = minimized
  }

  private fun calculateOverlaySize(): Pair<Int, Int> {
    if (overlayMinimized) {
      val size = dp(42)
      return Pair(size, size)
    }

    val bounds = displayBounds()
    val shortSide = min(bounds.first, bounds.second)
    val contentSize = (shortSide * overlayScale)
      .roundToInt()
      .coerceIn(
        (shortSide * MIN_SCALE).roundToInt(),
        (shortSide * MAX_SCALE).roundToInt(),
      )
    val barSize = dp(40)
    return when (overlayTabPosition) {
      LEFT_TAB_POSITION, RIGHT_TAB_POSITION -> Pair(contentSize + barSize, contentSize)
      else -> Pair(contentSize, contentSize + barSize)
    }
  }

  private fun displayBounds(): Pair<Int, Int> {
    val manager = windowManager ?: windowContext?.getSystemService(WindowManager::class.java)
      ?: getSystemService(WindowManager::class.java)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      val bounds = manager.currentWindowMetrics.bounds
      return Pair(bounds.width(), bounds.height())
    }

    val metrics = DisplayMetrics()
    @Suppress("DEPRECATION")
    manager.defaultDisplay.getMetrics(metrics)
    return Pair(metrics.widthPixels, metrics.heightPixels)
  }

  private fun createOverlayContext(targetDisplayId: Int): Context {
    val manager = getSystemService(DisplayManager::class.java) ?: return this
    val target = manager.displays.firstOrNull { display -> display.displayId == targetDisplayId }
      ?: manager.displays.firstOrNull()
      ?: return this
    return createDisplayContext(target)
  }

  private fun canDrawOverlay(): Boolean {
    return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)
  }

  private fun clampScale(value: Double): Double {
    return value.coerceIn(MIN_SCALE, MAX_SCALE)
  }

  private fun normalizeAppearance(value: String): String {
    return when (value) {
      GAME_GLASS_APPEARANCE -> GAME_GLASS_APPEARANCE
      "solidDark" -> "solidDark"
      else -> DEFAULT_APPEARANCE
    }
  }

  private fun normalizeTabPosition(value: String): String {
    return when (value) {
      TOP_TAB_POSITION -> TOP_TAB_POSITION
      BOTTOM_TAB_POSITION -> BOTTOM_TAB_POSITION
      LEFT_TAB_POSITION -> LEFT_TAB_POSITION
      RIGHT_TAB_POSITION -> RIGHT_TAB_POSITION
      else -> DEFAULT_TAB_POSITION
    }
  }

  private fun isInDragRegion(view: View, event: MotionEvent): Boolean {
    val barSize = dp(40).toFloat()
    val dragSize = dp(40).toFloat()
    val width = view.width.toFloat()
    val height = view.height.toFloat()
    return when (overlayTabPosition) {
      BOTTOM_TAB_POSITION -> event.y >= height - barSize && event.x <= dragSize
      LEFT_TAB_POSITION -> event.x <= barSize && event.y <= dragSize
      RIGHT_TAB_POSITION -> event.x >= width - barSize && event.y <= dragSize
      else -> event.y <= barSize && event.x <= dragSize
    }
  }

  private fun applyNativeWindowEffects(params: WindowManager.LayoutParams) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      params.flags = params.flags and WindowManager.LayoutParams.FLAG_BLUR_BEHIND.inv()
      params.blurBehindRadius = 0
    }
  }

  private fun applyKeyboardFocus(params: WindowManager.LayoutParams) {
    params.flags = if (keyboardActive) {
      params.flags and WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE.inv()
    } else {
      params.flags or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
    }
  }

  private fun dp(value: Int): Int {
    return (value * resources.displayMetrics.density).roundToInt()
  }

  private fun getMapsTreeUri(): Uri? {
    val uri = getSharedPreferences(PREFS_NAME, MODE_PRIVATE).getString(MAPS_TREE_URI_KEY, null)
    return uri?.let { Uri.parse(it) }
  }

  private fun getMapsFolderName(): String? {
    val treeUri = getMapsTreeUri() ?: return null
    return queryDisplayName(treeUri) ?: treeUri.lastPathSegment ?: "Selected Maps folder"
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
