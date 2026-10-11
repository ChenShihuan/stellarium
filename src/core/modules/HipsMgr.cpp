/*
 * Stellarium
 * Copyright (C) 2017 Guillaume Chereau
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

#include "HipsMgr.hpp"
#include "StelHips.hpp"
#include "StelPainter.hpp"
#include "StelCore.hpp"
#include "StelApp.hpp"
#include "StelTranslator.hpp"
#include "StelUtils.hpp"

#include <QNetworkReply>
#include <QSettings>
#include <QSignalBlocker>
#include <QTimer>

Q_LOGGING_CATEGORY(HiPS,"stel.HiPS", QtInfoMsg)

namespace
{
struct SpectralDataset
{
	const char* id;
	const char* title;
	const char* band;
	const char* surveyUrl;
	const char* source;
	const char* coverage;
	const char* license;
	const char* attribution;
};

const QList<SpectralDataset>& spectralDatasetCatalog()
{
	static const QList<SpectralDataset> catalog = {
		{"rass-xray", "RASS X-ray", "X-ray", "https://alasky.cds.unistra.fr/RASS/", "ROSAT All-Sky Survey", "全天球，曝光和能段因区域而异", "上游条款待逐产品核验", "MPE / CDS"},
		{"galex-nuv", "GALEX NUV", "Ultraviolet", "https://alasky.cds.unistra.fr/GALEX/GALEXGR6_7_NUV/", "GALEX GR6/7", "约 78.8% 天区覆盖，存在观测空洞", "上游条款待逐产品核验", "STScI / NASA"},
		{"2mass-color", "2MASS Color", "Near infrared", "https://alasky.cds.unistra.fr/2MASS/Color/", "2MASS J/H/K", "近红外 J/H/K 合成，接近全天覆盖", "上游条款待逐产品核验", "UMass / IPAC / Caltech"}
	};
	return catalog;
}

bool isSpectralSurveyUrl(const QString& url)
{
	for (const SpectralDataset& descriptor : spectralDatasetCatalog())
	{
		if (url == QString::fromLatin1(descriptor.surveyUrl)) return true;
	}
	return false;
}
}

HipsMgr::HipsMgr()
{
	setObjectName("HipsMgr");
	connect(this, &HipsMgr::surveysChanged, this, &HipsMgr::restoreVisibleSurveys);
}

HipsMgr::~HipsMgr()
{
#if (QT_VERSION<QT_VERSION_CHECK(6,0,0))
	// This function is no longer available in Qt6. We assume it is OK to run the code in any case, even if we were not connected.
	if (StelApp::getInstance().getNetworkAccessManager()->networkAccessible()==QNetworkAccessManager::Accessible)
#endif
	{
		// Store active HiPS to config.ini if network is available
		QSettings* conf = StelApp::getInstance().getSettings();
		conf->beginGroup("hips");
		conf->setValue("show", getFlagShow());
		conf->setValue("show_atmospheric_extinction", getFlagShowAtmosphericExtinction());

		// remove 0.18.0 scheme
		conf->remove("visible");

		QStringList surveyUrls;
		for (auto &survey: surveys)
		{
			if (survey->isVisible() && survey->planet.isEmpty() && !isSpectralSurveyUrl(survey->getUrl()))
				surveyUrls << survey->getUrl();
		}

		int surveyListSize = surveyUrls.count();
		if (surveyListSize==0)
		{
			// remove old urls
			conf->remove("surveys");
		}
		else
		{
			conf->beginWriteArray("surveys");
			for(int i=0;i<surveyListSize;i++)
			{
				conf->setArrayIndex(i);
				conf->setValue("url", surveyUrls.at(i));
			}
			conf->endArray();
		}

		conf->remove("surveySettings");
		int settingsIndex = 0;
		conf->beginWriteArray("surveySettings");
		for (auto &survey: surveys)
		{
			if (survey->isPlanetarySurvey() || survey->hasDefaultDisplaySettings() || isSpectralSurveyUrl(survey->getUrl()))
				continue;
			conf->setArrayIndex(settingsIndex++);
			conf->setValue("url", survey->getUrl());
			conf->setValue("gamma", survey->getGamma());
			conf->setValue("saturation", survey->getSaturation());
			conf->setValue("brightness", survey->getBrightness());
			conf->setValue("contrast", survey->getContrast());
			conf->setValue("opacity", survey->getOpacity());
			conf->setValue("colorChannel", survey->getColorChannel());
			conf->setValue("invertedColors", survey->getInvertedColors());
		}
		conf->endArray();

		conf->endGroup();
		conf->sync();
	}
}

void HipsMgr::loadSources()
{
	if (state != Created)
		return; // Already loaded.

	state = Loading;
	emit stateChanged(state);
	QSettings* conf = StelApp::getInstance().getSettings();
	conf->beginGroup("hips");

	// Start to load survey lists
	QStringList sources;
	int size = conf->beginReadArray("sources");
	for (int i = 0; i < size; i++)
	{
		conf->setArrayIndex(i);
		sources << conf->value("url").toString();
	}
	conf->endArray();

	// Use alasky (all pixelate surveys from MocServer) & data.stellarium.org if there are not values:
	if (sources.isEmpty())
	{
		sources << "http://alasky.u-strasbg.fr/MocServer/query?*/P/*&get=record"
			<< "https://data.stellarium.org/surveys/hipslist";
	}

	for (QUrl source: std::as_const(sources))
	{
		if (source.scheme().isEmpty()) source.setScheme("file");
		QNetworkRequest req = QNetworkRequest(source);
		req.setRawHeader("User-Agent", StelUtils::getUserAgentString().toLatin1());
		QNetworkReply* networkReply = StelApp::getInstance().getNetworkAccessManager()->get(req);
		connect(networkReply, &QNetworkReply::finished, this, [=] {
			QByteArray data = networkReply->readAll();
			QList<HipsSurveyP> newSurveys = HipsSurvey::parseHipslist(source.toString(), data);
			for (HipsSurveyP &survey: newSurveys)
			{
				connect(survey.data(), &HipsSurvey::propertiesChanged, this, &HipsMgr::surveysChanged);
				connect(survey.data(), &HipsSurvey::visibleChanged, this, &HipsMgr::updateActiveSurveys);
				connect(survey.data(), &HipsSurvey::displaySettingsChanged, this, &HipsMgr::saveSurveySettings);
				emit gotNewSurvey(survey);
			}
			surveys += newSurveys;
			emit surveysChanged();
			nbSourcesLoaded++;
			if (nbSourcesLoaded == sources.size())
			{
				state = Loaded;
				emit stateChanged(state);
			}
		});
	}
	conf->endGroup();
}

void HipsMgr::init()
{
	QSettings* conf = StelApp::getInstance().getSettings();
	conf->beginGroup("hips");
	setFlagShow(conf->value("show", false).toBool());
	flagShowAtmosphericExtinction = conf->value("show_atmospheric_extinction", false).toBool();
	int size = conf->beginReadArray("surveys");
	conf->endArray();	
	conf->endGroup();
	bool hasVisibleSurvey = size>0 ? true: false;

#if (QT_VERSION<QT_VERSION_CHECK(6,0,0))
	// In Qt6 we don't have the online check. We could ping somewhere, or just live with it.
	// There is QNetworkInformation in Qt6.1, but it may give wrong results under certain circumstances.
	// https://doc.qt.io/qt-6/qnetworkinformation.html
	if (StelApp::getInstance().getNetworkAccessManager()->networkAccessible()==QNetworkAccessManager::NotAccessible)
	{
		setFlagShow(false);
		hasVisibleSurvey = false;
	}
#endif
	addAction("actionShow_Hips_Surveys", N_("Display Options"), N_("Toggle Hierarchical Progressive Surveys"), "flagShow", "Ctrl+Alt+D");
	addAction("actionShow_Hips_Surveys_dialog", N_("Display Options"), N_("Toggle HiPS dialog"), this, [this]{emit toggleDialog();});

	// Start loading the sources only after stellarium has time to set up the proxy.
	// We only do it if we actually have a visible survey.  Otherwise it's
	// better not to do it until the user open the survey ui so that we
	// don't make a systematic request to the hipslist files!
	if (hasVisibleSurvey)
		QTimer::singleShot(0, this, &HipsMgr::loadSources);
}


void HipsMgr::restoreVisibleSurveys()
{
	qCDebug(HiPS) << "HipsMgr::restoreVisibleSurveys()";
	QSettings* conf = StelApp::getInstance().getSettings();
	conf->beginGroup("hips");

	// Start to load survey lists
	int size = conf->beginReadArray("surveys");
	for (int i = 0; i < size; i++)
	{
		conf->setArrayIndex(i);
		QString url = conf->value("url").toString();
		if (!url.isEmpty())
		{
			qCDebug(HiPS) << "HiPS: Restore visible survey:" << url;
			HipsSurveyP survey=getSurveyByUrl(url);
			if (survey)
				survey->setVisible(true);
		}
	}
	conf->endArray();

	size = conf->beginReadArray("surveySettings");
	for (int i = 0; i < size; i++)
	{
		conf->setArrayIndex(i);
		const QString url = conf->value("url").toString();
		if (isSpectralSurveyUrl(url)) continue;
		HipsSurveyP survey = getSurveyByUrl(url);
		if (survey && !survey->isPlanetarySurvey())
		{
			const QSignalBlocker blocker(survey.data());
			survey->setDisplaySettings(conf->value("gamma", 1.).toFloat(),
			                           conf->value("saturation", 1.).toFloat(),
			                           conf->value("brightness", 1.).toFloat(),
			                           conf->value("contrast", 1.).toFloat(),
			                           conf->value("opacity", 1.).toFloat(),
			                           conf->value("colorChannel", HipsSurvey::ColorChannelRgb).toInt(),
			                           conf->value("invertedColors", false).toBool());
		}
	}
	conf->endArray();
	conf->endGroup();
}

void HipsMgr::saveSurveySettings() const
{
	QSettings* conf = StelApp::getInstance().getSettings();
	conf->beginGroup("hips");
	conf->remove("surveySettings");
	int settingsIndex = 0;
	conf->beginWriteArray("surveySettings");
	for (auto &survey: surveys)
	{
		if (survey->isPlanetarySurvey() || survey->hasDefaultDisplaySettings() || isSpectralSurveyUrl(survey->getUrl()))
			continue;
		conf->setArrayIndex(settingsIndex++);
		conf->setValue("url", survey->getUrl());
		conf->setValue("gamma", survey->getGamma());
		conf->setValue("saturation", survey->getSaturation());
		conf->setValue("brightness", survey->getBrightness());
		conf->setValue("contrast", survey->getContrast());
		conf->setValue("opacity", survey->getOpacity());
		conf->setValue("colorChannel", survey->getColorChannel());
		conf->setValue("invertedColors", survey->getInvertedColors());
	}
	conf->endArray();
	conf->endGroup();
}

void HipsMgr::deinit()
{
}

void HipsMgr::draw(StelCore* core)
{
	if (!visible) return;
	StelPainter sPainter(core->getProjection(StelCore::FrameJ2000));
	for (auto &survey: activeSurveys)
	{
		if (survey->isVisible() && survey->planet.isEmpty())
		{
			survey->draw(&sPainter, 2.0 * M_PI, Q_NULLPTR, flagShowAtmosphericExtinction);
		}
	}
}

void HipsMgr::update(double deltaTime)
{
	for (auto it = activeSurveys.begin(); it != activeSurveys.end();)
	{
		const auto &survey = *it;
		survey->fader.update(static_cast<int>(deltaTime * 1000));
		if (!survey->isVisible() && survey->fader.getInterstate() == 0.f)
			it = activeSurveys.erase(it);
		else
			++it;
	}
}

double HipsMgr::getCallOrder(StelModuleActionName actionName) const
{
	if (actionName==StelModule::ActionDraw)
		return 7;
	return 0;
}

HipsSurveyP HipsMgr::getSurveyByUrl(const QString &url)
{
	for (auto &survey: surveys)
	{
		if (survey->getUrl() == url) return survey;
	}
	return HipsSurveyP(Q_NULLPTR);
}

int HipsMgr::getVisibleSurveyCount() const
{
	int count = 0;
	for (const auto& survey : surveys)
		if (survey->isVisible() && !survey->isPlanetarySurvey())
			++count;
	return count;
}

QJsonArray HipsMgr::getSpectralDatasets() const
{
	QJsonArray datasets;
	for (const SpectralDataset& descriptor : spectralDatasetCatalog())
	{
		QJsonObject item;
		const QString id = QString::fromLatin1(descriptor.id);
		const HipsSurveyP survey = spectralSurveys.value(id);
		item["id"] = id;
		item["title"] = QString::fromLatin1(descriptor.title);
		item["band"] = QString::fromLatin1(descriptor.band);
		item["source"] = QString::fromLatin1(descriptor.source);
		item["coverage"] = QString::fromLatin1(descriptor.coverage);
		item["license"] = QString::fromLatin1(descriptor.license);
		item["attribution"] = QString::fromLatin1(descriptor.attribution);
		item["licenseReviewRequired"] = true;
		item["networkPolicy"] = QStringLiteral("user-initiated");
		item["timeoutSeconds"] = 12;
		item["surveyUrl"] = QString::fromLatin1(descriptor.surveyUrl);
		item["available"] = true;
		item["enabled"] = survey && survey->isVisible();
		item["loading"] = survey && survey->isLoading();
		item["error"] = survey ? survey->getLastError() : QString();
		item["ready"] = survey && !survey->isLoading() && survey->getLastError().isEmpty()
			&& survey->property("properties").toJsonObject().contains("hips_order_max");
		datasets.append(item);
	}
	return datasets;
}

QJsonObject HipsMgr::getSpectralState() const
{
	QJsonObject state;
	state["enabled"] = false;
	state["datasetId"] = QString();
	state["loading"] = false;
	state["ready"] = false;
	state["error"] = QString();
	for (const SpectralDataset& descriptor : spectralDatasetCatalog())
	{
		const QString id = QString::fromLatin1(descriptor.id);
		const HipsSurveyP survey = spectralSurveys.value(id);
		if (!survey || !survey->isVisible()) continue;
		state["enabled"] = true;
		state["datasetId"] = id;
		state["loading"] = survey->isLoading();
		state["ready"] = !survey->isLoading();
		state["error"] = survey->getLastError();
		state["ready"] = !survey->isLoading() && survey->getLastError().isEmpty()
			&& survey->property("properties").toJsonObject().contains("hips_order_max");
		break;
	}
	return state;
}

bool HipsMgr::setSpectralView(const QString& datasetId, const bool enabled, QString* error)
{
	const SpectralDataset* descriptor = nullptr;
	for (const SpectralDataset& candidate : spectralDatasetCatalog())
	{
		if (datasetId == QString::fromLatin1(candidate.id))
		{
			descriptor = &candidate;
			break;
		}
	}
	if (!descriptor)
	{
		if (error) *error = QStringLiteral("unknown spectral dataset: %1").arg(datasetId);
		return false;
	}

	if (!enabled)
	{
		if (spectralSurveys.contains(datasetId)) spectralSurveys.value(datasetId)->setVisible(false);
		return true;
	}

	for (auto it = spectralSurveys.cbegin(); it != spectralSurveys.cend(); ++it)
		if (it.key() != datasetId && it.value()) it.value()->setVisible(false);

	HipsSurveyP survey = spectralSurveys.value(datasetId);
	if (!survey)
	{
		QMap<QString, QString> initialProperties;
		initialProperties.insert(QStringLiteral("obs_title"), QString::fromLatin1(descriptor->title));
		initialProperties.insert(QStringLiteral("hips_frame"), QStringLiteral("equatorial"));
		initialProperties.insert(QStringLiteral("hips_status"), QStringLiteral("public master clonableOnce"));
		survey = HipsSurveyP(new HipsSurvey(QString::fromLatin1(descriptor->surveyUrl), QStringLiteral("spectral"), QStringLiteral("equatorial"), QStringLiteral("image"), initialProperties));
		connect(survey.data(), &HipsSurvey::propertiesChanged, this, &HipsMgr::surveysChanged);
		connect(survey.data(), &HipsSurvey::visibleChanged, this, &HipsMgr::updateActiveSurveys);
		connect(survey.data(), &HipsSurvey::displaySettingsChanged, this, &HipsMgr::saveSurveySettings);
		spectralSurveys.insert(datasetId, survey);
		surveys.append(survey);
		emit gotNewSurvey(survey);
	}
	setFlagShow(true);
	survey->setVisible(true);
	emit surveysChanged();
	return true;
}

void HipsMgr::closeSpectralView()
{
	for (auto it = spectralSurveys.cbegin(); it != spectralSurveys.cend(); ++it)
		if (it.value()) it.value()->setVisible(false);
}

bool HipsMgr::getFlagShow(void) const
{
	return visible;
}

void HipsMgr::setFlagShow(bool b)
{
	if (visible != b)
	{
		visible = b;
		emit showChanged(b);
	}
	if (!b)
	{
		for (auto &survey: surveys)
		{
			if (survey->isVisible())
				survey->hideProgressBar();
		}
	}
}

void HipsMgr::setFlagShowAtmosphericExtinction(bool b)
{
	if (flagShowAtmosphericExtinction == b)
		return;
	flagShowAtmosphericExtinction = b;
	StelApp::immediateSave("hips/show_atmospheric_extinction", b);
	emit flagShowAtmosphericExtinctionChanged(b);
}

void HipsMgr::updateActiveSurveys()
{
	activeSurveys.clear();
	for (auto &survey: surveys)
	{
		if (survey->isVisible() || survey->fader.getInterstate() > 0.f)
			activeSurveys << survey;
	}
}
