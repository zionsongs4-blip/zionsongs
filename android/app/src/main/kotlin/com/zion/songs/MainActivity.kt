package com.example.zionsongs

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfDocument
import android.os.Handler
import android.os.Looper
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
	private val channelName = "zionsongs.pdf"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				if (call.method != "convertHtmlToPdf") {
					result.notImplemented()
					return@setMethodCallHandler
				}

				val html = call.argument<String>("html")
				if (html.isNullOrEmpty()) {
					result.error("INVALID_HTML", "HTML document is empty", null)
					return@setMethodCallHandler
				}
				convertHtmlToPdf(html, result)
			}
	}

	private fun convertHtmlToPdf(html: String, result: MethodChannel.Result) {
		Handler(Looper.getMainLooper()).post {
			val webView = WebView(this)
			webView.setBackgroundColor(Color.WHITE)
			webView.settings.javaScriptEnabled = true
			webView.settings.defaultFontSize = 16
			webView.setLayerType(WebView.LAYER_TYPE_SOFTWARE, null)
			webView.webViewClient = object : WebViewClient() {
				override fun onPageFinished(view: WebView, url: String) {
					view.evaluateJavascript(
						"document.documentElement.scrollHeight.toString()"
					) { heightValue ->
						val contentHeight = heightValue.trim('"').toIntOrNull()
							?: run {
								result.error("MEASURE_FAILED", "Could not measure HTML", null)
								view.destroy()
								return@evaluateJavascript
							}
						renderPdf(view, contentHeight, result)
					}
				}
			}
			webView.loadDataWithBaseURL(
				"file:///android_asset/flutter_assets/",
				html,
				"text/html",
				"UTF-8",
				null,
			)
		}
	}

	private fun renderPdf(
		webView: WebView,
		contentHeight: Int,
		result: MethodChannel.Result,
	) {
		val pageWidth = 794
		val pageHeight = 1123
		val totalHeight = maxOf(contentHeight, pageHeight)
		webView.measure(
			android.view.View.MeasureSpec.makeMeasureSpec(pageWidth, android.view.View.MeasureSpec.EXACTLY),
			android.view.View.MeasureSpec.makeMeasureSpec(totalHeight, android.view.View.MeasureSpec.EXACTLY),
		)
		webView.layout(0, 0, pageWidth, totalHeight)

		val document = PdfDocument()
		try {
			var pageNumber = 1
			var top = 0
			while (top < totalHeight) {
				val bitmap = Bitmap.createBitmap(pageWidth, pageHeight, Bitmap.Config.ARGB_8888)
				val canvas = Canvas(bitmap)
				canvas.drawColor(Color.WHITE)
				canvas.translate(0f, -top.toFloat())
				webView.draw(canvas)

				val page = document.startPage(
					PdfDocument.PageInfo.Builder(pageWidth, pageHeight, pageNumber).create(),
				)
				page.canvas.drawBitmap(bitmap, 0f, 0f, null)
				document.finishPage(page)
				bitmap.recycle()
				top += pageHeight
				pageNumber++
			}

			val output = ByteArrayOutputStream()
			document.writeTo(output)
			result.success(output.toByteArray())
		} catch (error: Exception) {
			result.error("PDF_RENDER_FAILED", error.message, null)
		} finally {
			document.close()
			webView.destroy()
		}
	}
}
