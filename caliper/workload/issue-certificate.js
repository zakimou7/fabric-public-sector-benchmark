'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');
const crypto = require('crypto');

/**
 * Workload — CertificateRegistry : issueCertificate(certId, holderId, holderName, certType, sha256, ipfsCid, appId, issuedBy, metaJson)
 *
 * يُنشئ شهادة جديدة لكل TX مع:
 *  - certId فريد (UUID)
 *  - sha256 فريد للـ PDF الوهمي
 *  - ipfsCid وهمي
 *  - metadata كاملة (wilaya, trainingCenter, issueDate...)
 */

const CERT_TYPES      = ['CDE', 'CFC', 'CAP', 'BTS', 'university'];
const WILAYAS         = ['biskra', 'algiers', 'oran', 'constantine', 'annaba', 'setif', 'batna'];
const TRAINING_CENTERS = ['CFPA Biskra', 'INSFP Algiers', 'CPA Oran', 'CFPA Constantine'];
const EDU_LEVELS      = ['license', 'master', 'engineer', 'bac', 'bts'];
const COURSE_NAMES    = [
  'Entrepreneurship & Business Creation',
  'Digital Marketing',
  'Web Development',
  'Accounting & Finance',
  'Project Management',
  'Electrical Engineering',
];
const FIRST_NAMES     = ['Mohamed', 'Fatima', 'Ahmed', 'Amina', 'Youcef', 'Nour', 'Karim', 'Sara'];
const LAST_NAMES      = ['Benali', 'Boudiaf', 'Cherif', 'Hamidi', 'Mansouri', 'Belkadi', 'Khelil'];

class IssueCertificateWorkload extends WorkloadModuleBase {
  constructor() {
    super();
    this.txCount = 0;
  }

  async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
    await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
    this.workerIndex = workerIndex;
    this.contractId  = roundArguments.contractId  || 'documentregistry';
    this.channelName = roundArguments.channelName || 'nesdachannel';
  }

  async submitTransaction() {
    this.txCount++;

    // IDs فريدة
    const certId     = `CERT-${this.workerIndex}-${this.txCount}-${Date.now()}`;
    const holderId   = `HOLDER-${this.workerIndex}-${this.txCount}`;

    // اسم صاحب الشهادة
    const firstName  = FIRST_NAMES[this.txCount % FIRST_NAMES.length];
    const lastName   = LAST_NAMES[this.txCount  % LAST_NAMES.length];
    const holderName = `${firstName} ${lastName}`;

    const certType   = CERT_TYPES[this.txCount % CERT_TYPES.length];

    // SHA-256 + CID وهميَّان لـ PDF الشهادة
    const rawData = `${certId}:${holderId}:${Date.now()}:${Math.random()}`;
    const sha256  = crypto.createHash('sha256').update(rawData).digest('hex');
    const ipfsCid = 'Qm' + crypto.randomBytes(22).toString('hex');

    const applicationId = `APP-${(this.txCount % 1000) + 1}`;
    const issuedBy      = `cert-sup-${(this.txCount % 3) + 1}`;

    // رقم شهادة فريد
    const certNumber = `CDE-${new Date().getFullYear()}-${String(this.txCount).padStart(6, '0')}`;

    const meta = JSON.stringify({
      certificateNumber: certNumber,
      wilaya:            WILAYAS[this.txCount         % WILAYAS.length],
      trainingCenter:    TRAINING_CENTERS[this.txCount % TRAINING_CENTERS.length],
      issueDate:         new Date().toISOString().split('T')[0],
      educationLevel:    EDU_LEVELS[this.txCount       % EDU_LEVELS.length],
      courseName:        COURSE_NAMES[this.txCount     % COURSE_NAMES.length],
    });

    const request = {
      contractId:        this.contractId,
      contractFunction:  'issueCertificate',
      contractArguments: [
        certId,
        holderId,
        holderName,
        certType,
        sha256,
        ipfsCid,
        applicationId,
        issuedBy,
        meta,
      ],
      channelName: this.channelName,
      readOnly:    false,
    };

    await this.sutAdapter.sendRequests(request);
  }
}

module.exports.createWorkloadModule = () => new IssueCertificateWorkload();
